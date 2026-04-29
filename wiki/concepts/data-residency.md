---
title: Data Residency
category: concept
summary: Some workloads carry contractual or regulatory constraints on where data can be stored and processed. NW-002 (Nationwide) is the first such workload — it forces a US AWS region instead of Bluerush's ca-central-1 default.
tags: [data-residency, compliance, regions, principle, vendor]
sources: 1
updated: 2026-04-29
---

# Data Residency

The rule that **where your bytes physically live matters**. Some clients impose contractual data-residency requirements, some regulators impose them by jurisdiction. Once flagged, residency drives a chain of architectural decisions: AWS region, KMS key location, S3 bucket region, where compute can run, where logs are aggregated, even where backups can replicate to.

---

## Bluerush Default

Bluerush's primary region is `ca-central-1` (with `us-east-1` for DR). This default works for Bluerush-internal and Canadian client workloads.

## Exception: NW-002 / Nationwide

[[entities/nationwide]] requires that **all data manipulation happen on US soil**. This rules out `ca-central-1` for the NW-002 pipeline — the drop bucket, processing compute, master list storage, and any DB used for dedup must all be in a US AWS region (`us-east-1`, `us-east-2`, or `us-west-2` are the obvious candidates). See [[sources/nw-002-pet-data-automation]].

## Architectural Knock-Ons

When residency forces a region change, these all need to follow:

| Resource | Implication |
|---|---|
| S3 buckets | Must be created in the residency-compliant region; bucket replication can only target compliant regions |
| KMS keys | Per-region; create a US-region CMK for NW-002 instead of reusing the Canadian one |
| Compute | Lambda / EC2 / ECS for the pipeline must run in a US region |
| Logs | CloudWatch Logs are per-region; aggregation into a Canadian log archive may violate residency |
| Backups | Cross-region snapshot copy must be to another compliant region |
| IAM roles | Roles are global, but session activity and CloudTrail event capture follow the region — keep both audit trails available |
| DR | DR target region must also be compliant |

## How To Handle Multi-Residency Workloads

- **Per-workload account boundary** — give residency-constrained workloads their own AWS member account. Then SCPs ([[entities/aws-organizations]]) can deny `*` actions outside permitted regions, providing a structural guarantee instead of a process one.
- **Region allowlist via SCP** — `aws:RequestedRegion` condition keys block API calls to non-compliant regions before they happen.
- **Tag everything with residency class** — `data-residency: us-only`, `data-residency: ca-only`, `data-residency: any`. Audit scripts can then enumerate non-compliant resources.

## Open Items for NW-002

- Choose the US AWS region (suggest `us-east-2` for cost; `us-east-1` for service availability)
- Decide whether NW-002 lives in a dedicated AWS member account
- Define the SCP region allowlist
- Document the runbook for the case where Bluerush ops needs to operate on the workload from a Canadian operator workstation (the operator can `Use-STSRole` into the US account; the data never leaves US-region resources)

## See Also

- [[sources/nw-002-pet-data-automation]]
- [[entities/nationwide]], [[entities/bluerush]], [[entities/aws-organizations]]
- [[concepts/sts-assume-role-pattern]]
- [[concepts/blast-radius-management]]
