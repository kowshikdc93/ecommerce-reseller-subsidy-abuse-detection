# Network Analysis Approach: Multi-Account Cluster Detection

**Author:** K M Kadir Koushik

---

## Overview

The multi-account cluster detection in this project is built on a graph-based analysis approach where buyer accounts are nodes and shared identifiers between accounts are edges. The goal is to identify clusters of accounts that are more densely connected than would be expected from genuine household behavior.

---

## Graph Structure

**Nodes:** Individual buyer accounts  
**Edges:** Shared identifiers between two accounts  
**Edge weight:** Number of identifier types shared (linkage strength, 1 to 4)  
**Cluster:** A connected subgraph of accounts where every node is reachable from every other node through one or more edges

---

## Identifier Types Used as Edges

| Identifier | Source | Notes |
|---|---|---|
| Device fingerprint (UMID) | Order checkout events | Persists across account changes on the same physical device |
| IP address | Order checkout events | Less reliable due to shared WiFi and dynamic IP allocation; used as supporting signal only |
| Phone number | Order checkout events (shipping phone) | High reliability; buyers rarely share phone numbers across unrelated accounts |
| Email address | Order checkout events | High reliability for exact match; fuzzy matching requires preprocessing |

---

## Linkage Strength Scoring

Each account pair receives a linkage strength score equal to the number of distinct identifier types shared:

| Linkage Strength | Identifiers Shared | Confidence Level |
|---|---|---|
| 1 | One identifier type | Low: possible coincidence (shared WiFi, family device) |
| 2 | Two identifier types | Medium: unlikely to be coincidental |
| 3 | Three identifier types | High: strongly indicative of same actor |
| 4 | All four identifier types | Very High: near-certain same actor |

For cluster classification, a minimum linkage strength of 2 is recommended to filter out weak coincidental connections.

---

## Cluster Size Distribution as a Signal

The cluster size distribution separates genuine households from reseller networks:

**Genuine household pattern:**
- 2 to 3 linked accounts
- Typically 1 to 2 shared identifiers (family device or shared WiFi)
- Low subsidy consumption per account
- Normal purchase patterns across diverse product categories

**Reseller network pattern:**
- 5 or more linked accounts
- Multiple shared identifier types per account pair
- High subsidy consumption concentrated in a single high-value category
- Purchases at maximum quantity limit per account
- Near-zero post-campaign return activity

---

## SQL Implementation Approach

The network analysis in `sql/03_account_linkage_network.sql` implements this graph analysis within the constraints of ODPS SQL:

1. **Edge creation:** Four separate CTEs generate account pair edges for each identifier type
2. **UNION deduplication:** UNION (not UNION ALL) merges all edge types and deduplicates account pairs
3. **Linkage strength aggregation:** COUNT(DISTINCT linkage_type) per account pair produces the edge weight
4. **Cluster size computation:** Self-join aggregation counts the number of distinct accounts each buyer is connected to, approximating the connected component size without a full graph traversal
5. **Classification:** Threshold-based classification flags accounts exceeding the cluster size and linkage strength criteria

---

## Python Extension (Graph Traversal)

For full connected component identification beyond what SQL self-joins can efficiently compute, the Python NetworkX library was used as a complement to the SQL analysis:

```python
import networkx as nx
import pandas as pd

# Load account pair edges from SQL output
edges_df = pd.read_csv('account_linkage_pairs.csv')

# Build undirected graph
G = nx.Graph()
for _, row in edges_df.iterrows():
    G.add_edge(row['buyer_id_1'], row['buyer_id_2'],
               weight=row['linkage_strength'])

# Find connected components (clusters)
components = list(nx.connected_components(G))

# Classify clusters by size
cluster_classification = []
for component in components:
    size = len(component)
    risk = ('HIGH RISK' if size > 4
            else 'MEDIUM RISK' if size > 2
            else 'LOW RISK')
    for buyer_id in component:
        cluster_classification.append({
            'buyer_id': buyer_id,
            'cluster_size': size,
            'risk_classification': risk
        })

cluster_df = pd.DataFrame(cluster_classification)
```

The Python output was joined back to the transaction data to enrich the SQL analysis with true connected component sizes for the most complex network structures.

---

## Limitations and Future Improvements

**Fuzzy matching:** The current implementation uses exact identifier matching. Actors who use slight variations in phone numbers or addresses to avoid detection are partially resistant to this approach. Incorporating fuzzy string matching (Levenshtein distance on address fields, phone number normalization) would reduce this gap.

**Dynamic IP filtering:** IP addresses that are associated with known shared infrastructure (mobile carrier NAT, commercial VPN ranges, public WiFi) should be excluded from edge creation to reduce false positive connections from coincidental IP sharing.

**Temporal edge weighting:** All edges are currently treated as equal regardless of when the shared identifier was observed. Adding a recency decay to edge weights would prioritize recent connections over historical ones, making the cluster detection more responsive to current behavior.
