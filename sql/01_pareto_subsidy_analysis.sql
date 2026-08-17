-- ============================================================
-- 01_PARETO_SUBSIDY_ANALYSIS.SQL
-- Reseller Subsidy Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Identifies the concentration of campaign subsidy consumption
--   across the buyer population. Confirms whether a small
--   minority of buyers is consuming a disproportionate majority
--   of total platform subsidies (the 80/20 or Pareto effect).
--
-- Key insight:
--   In a healthy campaign, subsidies should be distributed
--   across a broad buyer base driving genuine acquisition.
--   When a small cohort captures the majority of subsidies,
--   it signals targeted exploitation rather than organic demand.
--
-- Output interpretation:
--   The cumulative_subsidy_share column shows the running
--   percentage of total subsidies consumed as buyers are
--   ranked from highest to lowest consumption. A steep early
--   curve (e.g. top 2% consuming 80%+ of subsidies) confirms
--   the Pareto concentration pattern.
-- ============================================================

WITH campaign_subsidy_per_buyer AS (
    -- Total subsidy consumed per buyer during the campaign window
    SELECT  t.venture
            ,t.buyer_id
            ,COUNT(DISTINCT t.order_number)                 AS total_orders
            ,COUNT(DISTINCT t.line_item_id)                 AS total_items
            ,COUNT(DISTINCT t.sku_id)                       AS distinct_skus
            ,SUM(t.actual_gmv * t.exchange_rate)            AS total_gmv_usd
            ,SUM(s.platform_discount_total * t.exchange_rate)
                                                            AS total_platform_subsidy_usd
            ,SUM(s.platform_collectible_discount * t.exchange_rate)
                                                            AS total_collectible_discount_usd
            ,SUM(s.platform_shipping_discount * t.exchange_rate)
                                                            AS total_shipping_discount_usd

    FROM    analytics.transaction_line_items t
    JOIN    analytics.subsidy_transactions s
    ON      t.order_number  = s.order_number
    AND     t.line_item_id  = s.line_item_id
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2')
    AND     t.is_fulfilled = 1
    AND     t.payment_method IS NOT NULL
    -- Campaign window filter (replace with actual campaign dates)
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN 'CAMPAIGN_START_DATE' AND 'CAMPAIGN_END_DATE'
    -- Focus on high-value category where abuse was concentrated
    AND     t.category_level1_name = 'TARGET_CATEGORY'
    GROUP BY t.venture, t.buyer_id
)

,ranked_buyers AS (
    SELECT  venture
            ,buyer_id
            ,total_orders
            ,total_items
            ,distinct_skus
            ,total_gmv_usd
            ,total_platform_subsidy_usd
            ,total_collectible_discount_usd
            ,total_shipping_discount_usd
            -- Rank buyers by total subsidy consumed (highest first)
            ,ROW_NUMBER() OVER (
                PARTITION BY venture
                ORDER BY total_platform_subsidy_usd DESC
            )                                               AS buyer_rank
            -- Total buyers in venture for percentile calculation
            ,COUNT(*) OVER (PARTITION BY venture)           AS total_buyers
            -- Total subsidy for cumulative share calculation
            ,SUM(total_platform_subsidy_usd) OVER (
                PARTITION BY venture
            )                                               AS venture_total_subsidy_usd

    FROM    campaign_subsidy_per_buyer
)

SELECT  venture
        ,buyer_rank
        ,buyer_id
        ,total_orders
        ,total_items
        ,distinct_skus
        ,ROUND(total_gmv_usd, 2)                            AS total_gmv_usd
        ,ROUND(total_platform_subsidy_usd, 2)               AS total_platform_subsidy_usd
        ,ROUND(total_collectible_discount_usd, 2)           AS total_collectible_discount_usd
        -- Buyer's percentile rank in the subsidy distribution
        ,ROUND(buyer_rank * 100.0 / total_buyers, 2)        AS buyer_percentile
        -- This buyer's share of total venture subsidy
        ,ROUND(
            total_platform_subsidy_usd * 100.0
            / NULLIF(venture_total_subsidy_usd, 0)
        , 4)                                                AS individual_subsidy_share_pct
        -- Cumulative subsidy consumed up to and including this buyer
        ,ROUND(
            SUM(total_platform_subsidy_usd) OVER (
                PARTITION BY venture
                ORDER BY buyer_rank
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) * 100.0 / NULLIF(venture_total_subsidy_usd, 0)
        , 2)                                                AS cumulative_subsidy_share_pct
        -- Flag top concentration cohort for deeper investigation
        ,CASE
            WHEN buyer_rank * 100.0 / total_buyers <= 2
            THEN 'Top 2% Cohort'
            WHEN buyer_rank * 100.0 / total_buyers <= 5
            THEN 'Top 5% Cohort'
            WHEN buyer_rank * 100.0 / total_buyers <= 10
            THEN 'Top 10% Cohort'
            ELSE 'Remaining Population'
         END                                                AS buyer_cohort

FROM    ranked_buyers
ORDER BY venture ASC, buyer_rank ASC
;
