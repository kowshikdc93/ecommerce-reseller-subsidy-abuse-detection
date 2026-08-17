# Methodology: Reseller Subsidy Abuse Detection

**Author:** K M Kadir Koushik

---

## Problem Identification

The investigation was triggered by a post-campaign review that revealed an anomalous buyer retention pattern. Over 90% of buyers who purchased a specific high-value category during the campaign period showed no return activity in subsequent months. This dropout rate is structurally inconsistent with genuine customer acquisition and pointed to buyers motivated purely by the discount opportunity.

The Business Risk team was tasked with determining the scale of the exploitation, identifying the actors involved, and designing a preventive mechanism for future campaigns.

---

## Data Architecture

Three source tables formed the analytical foundation:

**Order Checkout Events**
Captures buyer-side order creation events including device fingerprint, IP address, and account identifiers. This table is the primary source for multi-account linkage analysis since it records the physical device and network connection used at the point of order placement.

**Transaction Line Items**
The core order fulfillment table containing product details, GMV, and item status. Used as the primary anchor for purchase pattern analysis and campaign window filtering.

**Subsidy Transactions**
Captures all forms of platform-funded discounts applied at item level including collectible discounts, vouchers, and shipping subsidies. Used to quantify the financial exposure per buyer and per cluster.

---

## Analytical Techniques

### Pareto Analysis
The first analytical step was to quantify the concentration of subsidy consumption across the buyer population. Buyers were ranked by total subsidy consumed and a cumulative share curve was constructed. This confirmed that a small minority of buyers was responsible for a disproportionate majority of total campaign subsidies, establishing the business case for deeper investigation.

### Basket Analysis
Examined purchase patterns for the same SKUs across linked buyer accounts within the campaign window. The core question was: are the same items being purchased by multiple accounts that share a physical device? High repetition of the same SKU across device-linked accounts at quantities far beyond personal consumption confirmed coordinated reseller purchasing.

### Network Graph Analysis
Built account linkage clusters using four identifier types: device fingerprint, IP address, phone number, and email address. For each buyer pair sharing at least one identifier, a linkage edge was created. The linkage strength was scored by counting how many identifier types each pair shared.

The cluster size distribution was the key output. A genuine multi-device household might share a device ID across two or three accounts (family members). A reseller network of ten or more accounts linked through multiple identifier types represents a fundamentally different pattern requiring intervention.

LISTAGG was used to record which linkage types connected each account pair, providing an audit trail for enforcement decisions.

### Time Series Analysis
Plotted daily subsidy consumption for the flagged cohort versus the genuine buyer cohort within the campaign window. The timing pattern was the key signal: resellers concentrate purchases in the first days of the campaign when the highest collectible discounts are available, then drop off as discount availability decreases. Genuine buyers show more distributed purchase timing driven by organic awareness and demand.

### Post-Campaign Retention Analysis
Tracked whether campaign buyers returned to place orders in the months following the campaign. This was the definitive validation step: resellers have no commercial reason to return without discounts, so their post-campaign retention approaches zero. Genuine buyers acquired through a campaign return at some natural rate reflecting the quality of the product experience and genuine demand.

---

## Shadow Run Validation

The risk engine rule was back-tested against the historical campaign dataset using a binary classification framework (true positive, false positive, true negative, false negative). Ground truth labels were derived from the network analysis findings.

The shadow run confirmed high accuracy in identifying the reseller population with minimal impact on genuine buyers. False positives were concentrated in borderline clusters where the linkage strength was weak or the account count was just above the threshold. These cases can be addressed through threshold calibration or secondary review before live blocking.

---

## Limitations

**Evolving evasion tactics:** The network analysis confirmed that actors had partially adapted their credential patterns to avoid existing detection algorithms by using slightly varied identifiers while maintaining connectivity through payment instruments. Future iterations of this framework should incorporate fuzzy matching on address and name fields to close this gap.

**Ground truth dependency:** The shadow run validation depends on the quality of the ground truth labels derived from the investigation. Borderline cases that were classified as genuine buyers may include actors who were not detected in the network analysis. The false negative rate should therefore be treated as a lower bound rather than a definitive measure.

**Payment card linkage:** Payment card BIN plus last 4 linkage was not included in this version due to data access restrictions. Including this linkage type would strengthen cluster detection, particularly for actors who vary device and IP but reuse the same payment instrument.
