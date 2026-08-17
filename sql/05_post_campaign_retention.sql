-- ============================================================
-- 05_POST_CAMPAIGN_RETENTION.SQL
-- Reseller Subsidy Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Tracks buyer return activity in the months following
--   the campaign to validate whether campaign purchases
--   represented genuine customer acquisition or purely
--   discount-driven one-time activity.
--
-- Key insight:
--   Genuine buyers acquired through a campaign continue
--   to return and purchase at some natural rate even without
--   ongoing discounts. Resellers have no reason to return
--   once campaign discounts have ended, so their post-campaign
--   retention approaches zero. A sharp divergence in
--   post-campaign retention between the flagged and genuine
--   cohorts is the final confirmation of reseller behavior.
--
-- Retention definition:
--   A buyer is "retained" in a post-campaign month if they
--   placed at least one order in that month regardless of
--   whether a discount was applied.
-- ============================================================

WITH campaign_buyers AS (
    -- All buyers who made a purchase during the campaign window
    SELECT  DISTINCT
            t.venture
            ,t.buyer_id
            ,CASE
                WHEN t.buyer_id IN (
                    SELECT buyer_id
                    FROM   analytics.flagged_reseller_accounts
                    WHERE  venture = t.venture
                )
                THEN 'Flagged Reseller Cohort'
                ELSE 'Genuine Buyer Cohort'
             END                                            AS buyer_cohort

    FROM    analytics.transaction_line_items t
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2')
    AND     t.is_fulfilled = 1
    AND     t.payment_method IS NOT NULL
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN 'CAMPAIGN_START_DATE' AND 'CAMPAIGN_END_DATE'
    AND     t.category_level1_name = 'TARGET_CATEGORY'
)

,post_campaign_activity AS (
    -- Track whether campaign buyers ordered in each post-campaign month
    SELECT  t.venture
            ,t.buyer_id
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')  AS activity_month

    FROM    analytics.transaction_line_items t
    WHERE   t.ds = MAX_PT('analytics.transaction_line_items')
    AND     t.venture IN ('MARKET_CODE_1', 'MARKET_CODE_2')
    AND     t.is_fulfilled = 1
    AND     t.payment_method IS NOT NULL
    -- Post-campaign window: 3 months after campaign end
    AND     TO_CHAR(t.fulfillment_create_date, 'yyyy-mm-dd')
                BETWEEN 'POST_CAMPAIGN_START_DATE' AND 'POST_CAMPAIGN_END_DATE'
    GROUP BY t.venture, t.buyer_id
            ,TO_CHAR(t.fulfillment_create_date, 'yyyy-MM')
)

,retention_by_cohort AS (
    SELECT  cb.venture
            ,cb.buyer_cohort
            ,pa.activity_month
            ,COUNT(DISTINCT cb.buyer_id)                    AS cohort_size
            ,COUNT(DISTINCT pa.buyer_id)                    AS retained_buyers

    FROM    campaign_buyers cb
    LEFT JOIN post_campaign_activity pa
    ON      cb.buyer_id = pa.buyer_id
    AND     cb.venture  = pa.venture
    GROUP BY cb.venture, cb.buyer_cohort, pa.activity_month
)

SELECT  venture
        ,buyer_cohort
        ,activity_month
        ,cohort_size
        ,retained_buyers
        ,ROUND(
            retained_buyers * 100.0
            / NULLIF(cohort_size, 0)
        , 2)                                                AS retention_rate_pct
        -- Flag cohorts with near-zero post-campaign retention
        ,CASE
            WHEN retained_buyers * 100.0
                 / NULLIF(cohort_size, 0) < 5
            THEN 'VERY LOW: Likely Reseller (<5%)'
            WHEN retained_buyers * 100.0
                 / NULLIF(cohort_size, 0) < 15
            THEN 'BELOW BASELINE: Investigate'
            ELSE 'NORMAL RETENTION'
         END                                                AS retention_classification

FROM    retention_by_cohort
WHERE   activity_month IS NOT NULL
ORDER BY venture ASC, buyer_cohort ASC, activity_month ASC
;
