# Reseller Subsidy Abuse Detection
### E-Commerce Risk Analytics | Campaign Subsidy Integrity Framework

**Author:** K M Kadir Koushik  
**Domain:** Risk Analytics | Subsidy Fraud Detection | Multi-Account Abuse  
**Stack:** ODPS SQL (MaxCompute) | Alibaba Cloud Data Warehouse | Network Analysis (Python)  
**Venture:** South Asian E-Commerce Platform

---

## Overview

This project documents a full-cycle fraud detection and mitigation framework built to identify and prevent systematic exploitation of platform campaign subsidies by resellers operating coordinated multi-account networks.

The scheme involved a small but highly active cohort of buyers who used linked accounts connected through shared devices, payment instruments, phone numbers, and email addresses to purchase high-value items repeatedly at campaign discount rates, far exceeding what a genuine consumer would buy. By rotating across accounts, these actors bypassed per-user purchase limits and consumed a disproportionate share of the platform's subsidy budget.

The investigation was triggered by an anomalous buyer retention drop immediately following a major campaign, which indicated that a significant portion of campaign GMV was driven by non-genuine demand.

---

## The Problem

A post-campaign review revealed that over 90% of buyers who purchased a specific high-value category during the campaign showed no further platform activity in subsequent months. This sharp drop-off is inconsistent with genuine customer acquisition and pointed to reseller behavior: buyers motivated by the discount opportunity rather than genuine product need.

```
Campaign buyers showing no return activity:  >90%
Top buyer cohort share of total subsidies:   ~80% consumed by ~2% of buyers
Accounts per reseller network:               Typically more than 5 linked accounts
Accuracy of detection rule (shadow run):     99% of reseller clusters correctly identified
False positive rate:                         ~1%
```

---

## Root Cause: Multi-Account Subsidy Exploitation

Resellers bypassed platform purchase limits by spreading purchases across multiple buyer accounts linked through shared identifiers. A single reseller network could purchase many times the per-user limit of a high-value item during the campaign window by rotating through linked accounts.

Since campaign subsidies are funded by the platform to drive genuine customer acquisition and retention, consumption by resellers represents direct financial leakage with no long-term customer value return.

```
Per-account purchase limit:     N units (platform-defined)
Reseller network accounts:      5+ linked accounts
Effective units purchased:      N x (number of linked accounts)
Post-campaign retention:        Near zero (resellers do not return without discounts)
Subsidy ROI for reseller cohort: Negative for platform
```

---

## Methodology

### Data Sources

| Source | Purpose |
|---|---|
| `analytics.order_checkout_events` | Device fingerprint, IP address, buyer account at order creation |
| `analytics.transaction_line_items` | Item-level GMV, payment method, discount amounts, fulfillment status |
| `analytics.subsidy_transactions` | Platform-funded voucher and collectible discount values per order |

### Analytical Techniques

**1. Pareto Analysis**
Identified the concentration of subsidy consumption. Confirmed that a small minority of buyers consumed a disproportionate majority of total campaign subsidies, establishing the scale and severity of the problem before investing in deeper investigation.

**2. Basket Analysis**
Examined purchase patterns for duplicate SKUs across orders within the same time window per buyer cluster. Confirmed that the same items were being purchased repeatedly across linked accounts, far beyond any plausible personal consumption level.

**3. Network Graph Analysis**
Built account linkage graphs connecting buyer accounts through shared identifiers: device fingerprint, IP address, payment card, phone number, and email address. Clusters of accounts sharing two or more identifiers were classified as likely reseller networks. Cluster size distribution confirmed that the majority of flagged buyers operated networks significantly above the platform's baseline for genuine multi-account households.

**4. Time Series Analysis**
Plotted subsidy consumption against time within the campaign window. Confirmed that the abusive cohort concentrated purchases in the first days of the campaign when collectible discounts were most generous, and activity dropped sharply once discount availability decreased. Genuine buyers show more distributed purchase timing.

**5. Post-Campaign Retention Analysis**
Tracked buyer activity in the months following the campaign. Reseller cohort showed near-zero return activity compared to the genuine buyer cohort, confirming the subsidy-driven rather than demand-driven nature of their campaign purchases.

---

## Key Findings

### Finding 1: Extreme Subsidy Concentration
A small minority of buyers (approximately 2% of campaign buyers) consumed the majority of total platform subsidies during the campaign period. This concentration is far beyond what would be expected from genuine buyer behavior and confirmed targeted exploitation.

### Finding 2: Coordinated Multi-Account Networks
Within the flagged buyer cohort, the majority operated with more than five associated buyer accounts linked through shared identifiers. This confirmed systematic rather than opportunistic behavior.

### Finding 3: Maximum Limit Exploitation
Flagged accounts consistently purchased the maximum allowed quantity of high-value items per account. When one account reached its limit, purchases immediately shifted to another linked account, confirming deliberate limit circumvention.

### Finding 4: Campaign-Window Concentration
The abusive cohort concentrated activity in the first days of the campaign window when the highest subsidy values were available. Activity dropped sharply as collectible discount availability decreased, confirming discount-driven rather than demand-driven behavior.

### Finding 5: Near-Zero Post-Campaign Retention
Return purchase activity from the reseller cohort in the months following the campaign was negligible. This directly confirmed that the campaign GMV attributed to this cohort represented no genuine customer acquisition value for the platform.

### Finding 6: Shared Identifier Clustering
Network analysis revealed clusters of five or more linked accounts sharing two or more identifiers, with some clusters containing significantly more accounts. The linkage patterns showed evidence of deliberate adaptation to avoid detection by existing collusion algorithms, with actors using slightly varied credentials while maintaining connectivity through payment instruments.

---

## Risk Engine Rule

A real-time rule was designed for deployment in the platform's risk engine to block discount access for buyers whose purchase pattern matches the multi-account abuse profile:

```
IF buyer_is_in_multi_account_cluster == TRUE
   AND distinct_linked_accounts_purchasing_same_sku_last_7_days > 4
   AND discount_applied_on_order == TRUE
THEN
   block_discount_access_for_buyer
```

**Rule logic:**
- Buyer must be identified as part of a multi-account cluster (more than 4 linked accounts)
- The same SKU must have been purchased across more than 4 linked accounts within the past 7 days
- A discount or collectible must be applied on the triggering order

**Shadow run validation:**
The rule was back-tested on historical campaign data. It correctly identified the reseller cluster population at high accuracy while generating minimal false positives among genuine buyers. The false positive cases were concentrated in borderline clusters with weak linkage signals, which can be further refined through threshold calibration.

**Risk layer:** Real-time buyer risk evaluation at order confirmation

---

## Impact Assessment

| Impact Area | Description |
|---|---|
| Subsidy budget protection | Redirects campaign discounts from resellers to genuine buyers |
| Campaign ROI accuracy | Removes inflated GMV from campaign metrics, enabling more accurate performance measurement |
| Platform fairness | Genuine buyers gain access to limited-supply campaign offers that resellers were monopolising |
| Operational efficiency | Proactive rule prevents abuse at point of transaction, reducing post-campaign clawback effort |
| Customer trust | Fairer allocation of offers improves genuine buyer experience and platform trust |

---

## Repository Structure

```
ecommerce-reseller-subsidy-abuse-detection/
├── README.md                                    # This file
├── sql/
│   ├── 01_pareto_subsidy_analysis.sql           # Concentration analysis of subsidy consumption
│   ├── 02_basket_analysis.sql                   # Duplicate SKU purchase detection across accounts
│   ├── 03_account_linkage_network.sql           # Multi-account cluster identification via shared identifiers
│   ├── 04_time_series_analysis.sql              # Intra-campaign subsidy consumption timing analysis
│   ├── 05_post_campaign_retention.sql           # Post-campaign buyer return activity analysis
│   └── 06_risk_engine_rule_validation.sql       # Shadow run simulation for rule accuracy measurement
├── docs/
│   ├── methodology.md                           # Full analytical methodology
│   ├── findings.md                              # Pattern-level findings across all analyses
│   └── rule_design.md                          # Risk engine rule logic and validation approach
└── assets/
    └── network_analysis_approach.md             # Graph-based account linkage methodology
```

---

## Skills Demonstrated

- **Advanced ODPS SQL:** Multi-source join architecture, window functions, self-joins for network analysis, conditional aggregation, rolling time window analysis
- **Fraud Pattern Recognition:** Multi-account network detection, purchase limit circumvention analysis, subsidy concentration quantification, behavioral timing analysis
- **Network Analysis:** Graph-based account clustering using shared identifiers, cluster size distribution analysis, linkage strength scoring
- **Risk Engine Rule Design:** Behavioral rule logic, shadow run back-testing, false positive quantification, threshold calibration
- **Campaign Analytics:** Post-campaign retention cohort analysis, subsidy ROI assessment, campaign GMV quality measurement
- **Business Impact Quantification:** Translating fraud patterns into financial leakage estimates and platform ROI impact

---

*This project was conducted as part of a campaign integrity initiative at a major South Asian e-commerce platform. All table names, column names, schema references, company names, campaign names, financial figures, and specific thresholds have been anonymised or generalised for public sharing. The analytical logic, methodology, detection framework, and rule design are original work.*
