# Findings: Reseller Subsidy Abuse Detection

**Author:** K M Kadir Koushik

---

## Finding 1: Extreme Subsidy Concentration Confirms Targeted Exploitation

Pareto analysis revealed that a very small cohort of buyers consumed a disproportionate majority of total campaign subsidies. This concentration is far beyond what would arise from genuine buyer behavior in any campaign distribution model and confirmed that the budget was being systematically targeted rather than organically consumed.

The steep early curve in the cumulative subsidy share distribution is the clearest high-level signal of abuse. In a healthy campaign, the cumulative curve rises gradually as subsidies are distributed across a broad buyer base.

---

## Finding 2: Coordinated Multi-Account Networks Confirmed

Network analysis identified clusters of buyer accounts linked through shared device fingerprints, IP addresses, phone numbers, and email addresses. Within the flagged cohort, the majority of buyers operated as part of networks containing more accounts than would be expected for genuine multi-device households.

Linkage strength scoring confirmed that many account pairs shared more than one type of identifier, significantly increasing confidence in the coordinated nature of the network. The cluster size distribution showed a clear separation between the genuine population and the flagged cohort.

---

## Finding 3: Deliberate Purchase Limit Circumvention

Basket analysis confirmed that the same high-value SKUs were being purchased repeatedly across linked accounts at quantities far beyond plausible personal consumption. The pattern was consistent with a deliberate strategy to multiply the effective purchase limit by rotating across accounts within the same network.

Accounts consistently purchased at the maximum allowed quantity per SKU per account, then shifted purchases immediately to another linked account once the limit was reached. This rotation pattern has no explanation other than deliberate limit circumvention.

---

## Finding 4: Campaign-Timing Concentration Confirms Discount-Driven Intent

Time series analysis showed that the flagged cohort concentrated purchases in the opening days of the campaign when collectible discount values were highest, then reduced activity sharply as discount availability decreased. The genuine buyer cohort showed more distributed purchase timing consistent with organic awareness and demand.

The front-loading pattern in the reseller cohort is consistent with professional monitoring of campaign launches to capture the highest available discounts before other buyers or before subsidy budgets are exhausted.

---

## Finding 5: Near-Zero Post-Campaign Retention Confirms No Genuine Acquisition Value

Post-campaign retention analysis was the definitive finding. The flagged cohort showed near-zero return activity in the months following the campaign. The genuine buyer cohort showed meaningful return activity reflecting the platform's natural retention dynamics.

This finding directly quantifies the ROI impact of the abuse: the subsidy spend attributed to the reseller cohort generated no customer lifetime value for the platform. Every subsidy dollar consumed by a reseller is a dollar that could have been directed to a genuine buyer who would have returned and continued purchasing.

---

## Finding 6: Evasion Adaptation Detected

Network analysis revealed evidence that some actors had partially adapted their credential patterns in response to existing collusion detection algorithms. While account pairs were still detectable through payment instruments and other shared identifiers, some actors had diversified their device and address credentials to reduce detectability on those dimensions.

This finding underscores the importance of multi-identifier linkage. A detection system that relies on any single identifier type is more vulnerable to evasion than one that requires two or more independent identifiers to agree.

---

## Key Takeaway

The subsidy structure created a predictable target for resellers: high discount value on high-demand items with per-account purchase limits that could be circumvented through account multiplication. The platform's existing controls operated at account level, which was insufficient to detect network-level coordination.

The framework developed in this project operates at cluster level rather than account level, making it structurally harder to evade. The shadow run validation confirmed that the detection accuracy is high enough for deployment with minimal false positive risk to genuine buyers.
