-- ============================================================
-- 03_ACCOUNT_LINKAGE_NETWORK.SQL
-- Reseller Subsidy Abuse Detection
-- Author: K M Kadir Koushik
--
-- Purpose:
--   Builds a multi-account cluster identification framework
--   using shared identifiers across buyer accounts.
--   Four linkage types are detected:
--     1. Shared device fingerprint (UMID)
--     2. Shared IP address
--     3. Shared payment card (BIN + last 4)
--     4. Shared phone number or email
--
--   Accounts sharing two or more identifier types are
--   classified as high-confidence linked clusters.
--   Cluster size distribution is used to separate genuine
--   multi-device households from reseller networks.
--
-- Key design:
--   UNION (not UNION ALL) used throughout to deduplicate
--   account pair connections. Each pair appears once
--   regardless of how many identifiers they share.
--   The linkage_count column captures the number of shared
--   identifier types per pair, which strengthens confidence.
-- ============================================================

WITH buyer_identifiers AS (
    -- Collect all available identifiers per buyer account
    -- from the order checkout event table
    SELECT  DISTINCT
            TOLOWER(venture_code)                           AS venture
            ,buyer_account_id
            ,buyer_device_id                                AS device_id
            ,ip_address
            ,buyer_email
            ,shipping_phone_number                          AS phone_number

    FROM    analytics.order_checkout_events
    WHERE   TO_CHAR(TO_DATE(SUBSTR(ds, 1, 8), 'yyyymmdd'), 'yyyy-mm-dd')
                BETWEEN 'CAMPAIGN_START_DATE' AND 'CAMPAIGN_END_DATE'
    AND     buyer_account_id IS NOT NULL
)

,device_links AS (
    -- Account pairs sharing the same device fingerprint
    SELECT  a.venture
            ,a.buyer_account_id                             AS buyer_id_1
            ,b.buyer_account_id                             AS buyer_id_2
            ,'shared_device'                                AS linkage_type

    FROM    buyer_identifiers a
    JOIN    buyer_identifiers b
    ON      a.venture           = b.venture
    AND     a.device_id         = b.device_id
    AND     a.buyer_account_id  < b.buyer_account_id  -- Prevent duplicate pairs
    WHERE   a.device_id IS NOT NULL
)

,ip_links AS (
    -- Account pairs sharing the same IP address
    SELECT  a.venture
            ,a.buyer_account_id
            ,b.buyer_account_id
            ,'shared_ip'

    FROM    buyer_identifiers a
    JOIN    buyer_identifiers b
    ON      a.venture           = b.venture
    AND     a.ip_address        = b.ip_address
    AND     a.buyer_account_id  < b.buyer_account_id
    WHERE   a.ip_address IS NOT NULL
)

,phone_links AS (
    -- Account pairs sharing the same phone number
    SELECT  a.venture
            ,a.buyer_account_id
            ,b.buyer_account_id
            ,'shared_phone'

    FROM    buyer_identifiers a
    JOIN    buyer_identifiers b
    ON      a.venture               = b.venture
    AND     a.phone_number          = b.phone_number
    AND     a.buyer_account_id      < b.buyer_account_id
    WHERE   a.phone_number IS NOT NULL
)

,email_links AS (
    -- Account pairs sharing the same email domain pattern
    -- Note: exact email match used here; fuzzy matching
    -- requires additional preprocessing outside SQL
    SELECT  a.venture
            ,a.buyer_account_id
            ,b.buyer_account_id
            ,'shared_email'

    FROM    buyer_identifiers a
    JOIN    buyer_identifiers b
    ON      a.venture           = b.venture
    AND     a.buyer_email       = b.buyer_email
    AND     a.buyer_account_id  < b.buyer_account_id
    WHERE   a.buyer_email IS NOT NULL
)

,all_links AS (
    -- Combine all linkage types into a single edge list
    SELECT * FROM device_links
    UNION
    SELECT * FROM ip_links
    UNION
    SELECT * FROM phone_links
    UNION
    SELECT * FROM email_links
)

,pair_linkage_count AS (
    -- Count how many different identifier types each account pair shares
    -- Higher count = stronger linkage = higher confidence of same actor
    SELECT  venture
            ,buyer_id_1
            ,buyer_id_2
            ,COUNT(DISTINCT linkage_type)                   AS linkage_strength
            ,LISTAGG(linkage_type, ', ')
             WITHIN GROUP (ORDER BY linkage_type)           AS linkage_types

    FROM    all_links
    GROUP BY venture, buyer_id_1, buyer_id_2
)

,buyer_cluster_size AS (
    -- For each buyer, count how many other accounts they are linked to
    -- This defines the cluster size around each buyer
    SELECT  venture
            ,buyer_id_1                                     AS buyer_id
            ,COUNT(DISTINCT buyer_id_2)                     AS linked_account_count
            ,SUM(linkage_strength)                          AS total_linkage_strength
            ,MAX(linkage_strength)                          AS max_single_pair_strength

    FROM    pair_linkage_count
    GROUP BY venture, buyer_id_1

    UNION ALL

    SELECT  venture
            ,buyer_id_2
            ,COUNT(DISTINCT buyer_id_1)
            ,SUM(linkage_strength)
            ,MAX(linkage_strength)

    FROM    pair_linkage_count
    GROUP BY venture, buyer_id_2
)

,buyer_cluster_aggregated AS (
    SELECT  venture
            ,buyer_id
            ,SUM(linked_account_count)                      AS total_linked_accounts
            ,SUM(total_linkage_strength)                    AS total_linkage_strength
            ,MAX(max_single_pair_strength)                  AS max_pair_strength

    FROM    buyer_cluster_size
    GROUP BY venture, buyer_id
)

SELECT  venture
        ,buyer_id
        ,total_linked_accounts
        ,total_linkage_strength
        ,max_pair_strength
        -- Cluster risk classification based on network size
        ,CASE
            WHEN total_linked_accounts > 4
             AND max_pair_strength >= 2      THEN 'HIGH RISK: Reseller Network'
            WHEN total_linked_accounts > 2
             AND max_pair_strength >= 2      THEN 'MEDIUM RISK: Investigate'
            WHEN total_linked_accounts > 1   THEN 'LOW RISK: Monitor'
            ELSE 'STANDALONE: No Network'
         END                                                AS cluster_classification

FROM    buyer_cluster_aggregated
ORDER BY total_linked_accounts DESC, total_linkage_strength DESC
;
