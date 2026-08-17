-- ============================================================
-- 04_TIME_SERIES_ANALYSIS.SQL
-- Reseller Subsidy Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Analyzes the intra-campaign timing of subsidy consumption
--   to determine whether abusive buyers concentrated purchases
--   in the early high-discount window versus genuine buyers
--   who show more distributed purchase timing.
--
-- Key insight:
--   Resellers monitor campaign launches closely and act
--   immediately to capture the highest available discounts
--   before stock or subsidy budgets deplete. Genuine buyers
--   show more organic purchase timing distributed across
--   the campaign window. A sharp front-loading pattern in
--   the flagged cohort versus a flatter pattern in the
--   genuine cohort confirms intentional subsidy targeting.
-- ============================================================

WITH campaign_daily_subsidy AS (
    -- Daily subsidy consumption split by buyer cohort
    -- Flagged buyers identified from the account linkage analysis
    SELECT  TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')    AS purchase_day
            ,t.venture
            ,CASE
                WHEN t.buyer_id IN (
                    SELECT buyer_id
                    FROM   analytics.flagged_reseller_accounts
                    WHERE  venture = t.venture
                )
                THEN 'Flagged Reseller Cohort'
                ELSE 'Genuine Buyer Cohort'
             END                                                AS buyer_cohort
            ,COUNT(DISTINCT t.buyer_id)                         AS active_buyers
            ,COUNT(DISTINCT t.order_number)                     AS total_orders
            ,SUM(s.platform_discount_total * t.exchange_rate)   AS total_subsidy_usd
            ,SUM(s.platform_collectible_discount * t.exchange_rate)
                                                                AS collectible_discount_usd

    FROM    analytics.transaction_line_items t
    JOIN    analytics.subsidy_transactions s
    ON      t.order_number  = s.order_number
    AND     t.line_item_id  = s.line_item_id
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2')
    AND     t.is_fulfilled = 1
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN 'CAMPAIGN_START_DATE' AND 'CAMPAIGN_END_DATE'
    AND     t.category_level1_name = 'TARGET_CATEGORY'
    GROUP BY
        TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
        ,t.venture
        ,CASE
            WHEN t.buyer_id IN (
                SELECT buyer_id FROM analytics.flagged_reseller_accounts
                WHERE venture = t.venture
            )
            THEN 'Flagged Reseller Cohort'
            ELSE 'Genuine Buyer Cohort'
         END
)

,daily_with_cumulative AS (
    SELECT  purchase_day
            ,venture
            ,buyer_cohort
            ,active_buyers
            ,total_orders
            ,ROUND(total_subsidy_usd, 2)                    AS total_subsidy_usd
            ,ROUND(collectible_discount_usd, 2)             AS collectible_discount_usd
            -- Cumulative subsidy consumed within each cohort over the campaign
            ,ROUND(
                SUM(total_subsidy_usd) OVER (
                    PARTITION BY venture, buyer_cohort
                    ORDER BY purchase_day
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                )
            , 2)                                            AS cumulative_subsidy_usd
            -- Day number within campaign for front-loading analysis
            ,ROW_NUMBER() OVER (
                PARTITION BY venture, buyer_cohort
                ORDER BY purchase_day
            )                                               AS campaign_day_number
            -- Total campaign subsidy per cohort for share calculation
            ,SUM(total_subsidy_usd) OVER (
                PARTITION BY venture, buyer_cohort
            )                                               AS cohort_total_subsidy_usd

    FROM    campaign_daily_subsidy
)

SELECT  purchase_day
        ,venture
        ,buyer_cohort
        ,campaign_day_number
        ,active_buyers
        ,total_orders
        ,total_subsidy_usd
        ,collectible_discount_usd
        ,cumulative_subsidy_usd
        -- Share of cohort's total subsidy consumed by this day
        ,ROUND(
            cumulative_subsidy_usd * 100.0
            / NULLIF(cohort_total_subsidy_usd, 0)
        , 2)                                                AS cumulative_subsidy_share_pct
        -- Daily subsidy per active buyer (intensity measure)
        ,ROUND(
            total_subsidy_usd / NULLIF(active_buyers, 0)
        , 2)                                                AS subsidy_per_active_buyer_usd

FROM    daily_with_cumulative
ORDER BY venture ASC, buyer_cohort ASC, purchase_day ASC
;
