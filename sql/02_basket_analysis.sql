-- ============================================================
-- 02_BASKET_ANALYSIS.SQL
-- Reseller Subsidy Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Detects duplicate SKU purchases across linked buyer accounts
--   within a defined time window. Identifies buyers purchasing
--   the same items repeatedly across multiple accounts,
--   confirming deliberate purchase limit circumvention.
--
-- Key insight:
--   Genuine buyers purchasing the same high-value item across
--   multiple accounts is statistically rare and commercially
--   implausible. When the same SKU appears across 5+ linked
--   accounts within the campaign window, it confirms coordinated
--   reseller behavior rather than coincidental purchasing.
-- ============================================================

WITH campaign_purchases AS (
    -- All purchases during the campaign window for the target category
    SELECT  t.venture
            ,t.buyer_id
            ,t.order_number
            ,t.sku_id
            ,t.product_name
            ,t.deepest_category_name
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')  AS purchase_date
            ,t.paid_price * t.exchange_rate                     AS paid_price_usd
            ,s.platform_discount_total * t.exchange_rate        AS platform_subsidy_usd
            ,COUNT(DISTINCT t.line_item_id)                     AS items_ordered

    FROM    analytics.transaction_line_items t
    JOIN    analytics.subsidy_transactions s
    ON      t.order_number  = s.order_number
    AND     t.line_item_id  = s.line_item_id
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2')
    AND     t.is_fulfilled = 1
    AND     t.payment_method IS NOT NULL
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN 'CAMPAIGN_START_DATE' AND 'CAMPAIGN_END_DATE'
    AND     t.category_level1_name = 'TARGET_CATEGORY'
    GROUP BY
        t.venture, t.buyer_id, t.order_number, t.sku_id
        ,t.product_name, t.deepest_category_name
        ,TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
        ,t.paid_price * t.exchange_rate
        ,s.platform_discount_total * t.exchange_rate
)

,account_device_mapping AS (
    -- Link buyer accounts to device fingerprints
    -- Used to identify accounts sharing the same physical device
    SELECT  DISTINCT
            buyer_account_id                                AS buyer_id
            ,buyer_device_id
            ,venture_code                                   AS venture

    FROM    analytics.order_checkout_events
    WHERE   TO_CHAR(TO_DATE(SUBSTR(ds, 1, 8), 'yyyymmdd'), 'yyyy-mm-dd')
                BETWEEN 'CAMPAIGN_START_DATE' AND 'CAMPAIGN_END_DATE'
)

,linked_account_purchases AS (
    -- Join purchases to device mapping to identify
    -- same-device purchases of the same SKU
    SELECT  p1.venture
            ,p1.sku_id
            ,p1.product_name
            ,p1.deepest_category_name
            ,p1.buyer_id                                    AS buyer_id_1
            ,p2.buyer_id                                    AS buyer_id_2
            ,d1.buyer_device_id                             AS shared_device_id
            ,p1.purchase_date                               AS purchase_date_1
            ,p2.purchase_date                               AS purchase_date_2
            ,p1.paid_price_usd
            ,p1.platform_subsidy_usd                        AS subsidy_buyer_1
            ,p2.platform_subsidy_usd                        AS subsidy_buyer_2

    FROM    campaign_purchases p1
    JOIN    campaign_purchases p2
    ON      p1.sku_id   = p2.sku_id
    AND     p1.venture  = p2.venture
    AND     p1.buyer_id <> p2.buyer_id  -- Different buyer accounts
    JOIN    account_device_mapping d1
    ON      p1.buyer_id = d1.buyer_id
    AND     p1.venture  = d1.venture
    JOIN    account_device_mapping d2
    ON      p2.buyer_id = d2.buyer_id
    AND     p2.venture  = d2.venture
    -- Same physical device used by both accounts
    AND     d1.buyer_device_id = d2.buyer_device_id
)

,sku_cluster_summary AS (
    -- Aggregate to SKU level: how many linked account pairs
    -- purchased the same item using the same device
    SELECT  venture
            ,sku_id
            ,product_name
            ,deepest_category_name
            ,shared_device_id
            ,COUNT(DISTINCT buyer_id_1)                     AS distinct_buyer_accounts
            ,COUNT(*)                                        AS total_linked_purchase_pairs
            ,ROUND(SUM(subsidy_buyer_1 + subsidy_buyer_2), 2)
                                                            AS total_subsidy_from_linked_pairs_usd
            ,MIN(purchase_date_1)                           AS earliest_purchase_date
            ,MAX(purchase_date_2)                           AS latest_purchase_date

    FROM    linked_account_purchases
    GROUP BY venture, sku_id, product_name, deepest_category_name, shared_device_id
)

SELECT  venture
        ,sku_id
        ,product_name
        ,deepest_category_name
        ,shared_device_id
        ,distinct_buyer_accounts
        ,total_linked_purchase_pairs
        ,total_subsidy_from_linked_pairs_usd
        ,earliest_purchase_date
        ,latest_purchase_date
        -- Flag clusters exceeding legitimate multi-account household threshold
        ,CASE
            WHEN distinct_buyer_accounts > 4 THEN 'HIGH RISK: Likely Reseller Network'
            WHEN distinct_buyer_accounts > 2 THEN 'MEDIUM RISK: Investigate'
            ELSE 'LOW RISK: Monitor'
         END                                                AS cluster_risk_classification

FROM    sku_cluster_summary
ORDER BY distinct_buyer_accounts DESC, total_subsidy_from_linked_pairs_usd DESC
;
