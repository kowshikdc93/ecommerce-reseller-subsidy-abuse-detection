-- ============================================================
-- 06_RISK_ENGINE_RULE_VALIDATION.SQL
-- Reseller Subsidy Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Shadow run simulation to validate the accuracy of the
--   proposed risk engine rule before live deployment.
--   Tests the rule against historical campaign data to
--   measure true positive rate (resellers correctly blocked)
--   and false positive rate (genuine buyers incorrectly blocked).
--
-- Rule being validated:
--   IF buyer_is_in_multi_account_cluster == TRUE
--      AND distinct_linked_accounts_purchasing_same_sku_last_7_days > 4
--      AND discount_applied_on_order == TRUE
--   THEN block_discount_access
--
-- Output interpretation:
--   true_positive:  Reseller orders correctly identified and blocked
--   false_positive: Genuine buyer orders incorrectly flagged
--   true_negative:  Genuine buyer orders correctly allowed through
--   false_negative: Reseller orders missed by the rule
--
--   Rule accuracy = (true_positive + true_negative) / total_orders
--   Precision     = true_positive / (true_positive + false_positive)
--   Recall        = true_positive / (true_positive + false_negative)
-- ============================================================

WITH campaign_orders AS (
    -- All orders during campaign window with discount applied
    SELECT  t.venture
            ,t.buyer_id
            ,t.order_number
            ,t.sku_id
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')   AS order_date
            ,s.platform_discount_total * t.exchange_rate         AS platform_subsidy_usd
            -- Ground truth label from investigation findings
            ,CASE
                WHEN t.buyer_id IN (
                    SELECT buyer_id FROM analytics.flagged_reseller_accounts
                    WHERE venture = t.venture
                )
                THEN 'Reseller'
                ELSE 'Genuine'
             END                                                AS ground_truth_label

    FROM    analytics.transaction_line_items t
    JOIN    analytics.subsidy_transactions s
    ON      t.order_number = s.order_number
    AND     t.line_item_id = s.line_item_id
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2')
    AND     t.is_fulfilled = 1
    AND     s.platform_discount_total > 0  -- Only orders with discount applied
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN 'CAMPAIGN_START_DATE' AND 'CAMPAIGN_END_DATE'
    AND     t.category_level1_name = 'TARGET_CATEGORY'
)

,rolling_sku_purchases AS (
    -- For each order, count distinct linked accounts that purchased
    -- the same SKU in the prior 7 days (the rule's trigger condition)
    SELECT  o1.venture
            ,o1.buyer_id
            ,o1.order_number
            ,o1.sku_id
            ,o1.order_date
            ,o1.platform_subsidy_usd
            ,o1.ground_truth_label
            ,COUNT(DISTINCT o2.buyer_id)                         AS linked_accounts_same_sku_7d

    FROM    campaign_orders o1
    -- Self join: find other orders of the same SKU within 7 days
    LEFT JOIN campaign_orders o2
    ON      o1.venture  = o2.venture
    AND     o1.sku_id   = o2.sku_id
    AND     o1.buyer_id <> o2.buyer_id
    AND     o2.order_date BETWEEN DATE_ADD(o1.order_date, -7) AND o1.order_date
    -- Only count orders from linked accounts (same device or identifier)
    AND     o2.buyer_id IN (
                SELECT buyer_id_2
                FROM   analytics.account_linkage_pairs
                WHERE  buyer_id_1 = o1.buyer_id
                AND    venture    = o1.venture
                UNION
                SELECT buyer_id_1
                FROM   analytics.account_linkage_pairs
                WHERE  buyer_id_2 = o1.buyer_id
                AND    venture    = o1.venture
            )
    GROUP BY
        o1.venture, o1.buyer_id, o1.order_number
        ,o1.sku_id, o1.order_date
        ,o1.platform_subsidy_usd, o1.ground_truth_label
)

,rule_applied AS (
    -- Apply the rule logic and classify each order
    SELECT  venture
            ,buyer_id
            ,order_number
            ,sku_id
            ,order_date
            ,platform_subsidy_usd
            ,ground_truth_label
            ,linked_accounts_same_sku_7d
            -- Rule fires when linked accounts exceeds threshold
            ,CASE
                WHEN linked_accounts_same_sku_7d > 4 THEN 'BLOCKED'
                ELSE 'ALLOWED'
             END                                                AS rule_decision
            -- Classification matrix
            ,CASE
                WHEN linked_accounts_same_sku_7d > 4
                 AND ground_truth_label = 'Reseller'   THEN 'True Positive'
                WHEN linked_accounts_same_sku_7d > 4
                 AND ground_truth_label = 'Genuine'    THEN 'False Positive'
                WHEN linked_accounts_same_sku_7d <= 4
                 AND ground_truth_label = 'Genuine'    THEN 'True Negative'
                WHEN linked_accounts_same_sku_7d <= 4
                 AND ground_truth_label = 'Reseller'   THEN 'False Negative'
             END                                                AS classification

    FROM    rolling_sku_purchases
)

-- Summary validation metrics
SELECT  venture
        ,classification
        ,COUNT(DISTINCT order_number)                           AS order_count
        ,COUNT(DISTINCT buyer_id)                               AS buyer_count
        ,ROUND(SUM(platform_subsidy_usd), 2)                    AS subsidy_value_usd
        ,ROUND(
            COUNT(DISTINCT order_number) * 100.0
            / NULLIF(SUM(COUNT(DISTINCT order_number)) OVER (PARTITION BY venture), 0)
        , 2)                                                    AS pct_of_total_orders

FROM    rule_applied
GROUP BY venture, classification
ORDER BY venture ASC
        ,CASE classification
            WHEN 'True Positive'  THEN 1
            WHEN 'False Positive' THEN 2
            WHEN 'True Negative'  THEN 3
            WHEN 'False Negative' THEN 4
         END
;
