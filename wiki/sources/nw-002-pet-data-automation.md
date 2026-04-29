---
title: NW-002 — Nationwide Pet IndiVideo Data Automation Spec
category: source
summary: Replace manual Excel data manipulation by Nationwide's Shaun Ito with an automated drop-location → filter → enrich → upload pipeline. US-soil data residency is mandatory.
tags: [nw-002, nationwide, individeo, data-pipeline, automation, vendor, data-residency, key-person-risk]
sources: 1
updated: 2026-04-29
source_path: Projects/IV.Tools.NW/NW-002_SPECS.md.md
source_date: 2025-01
authors: [Bluerush product / NW account team]
ingested: 2026-04-29
---

# NW-002 — Nationwide Pet IndiVideo Data Automation

**Original**: `Projects/IV.Tools.NW/NW-002_SPECS.md.md` (note: filename has a doubled `.md` suffix in source)
**Project**: NW-002 Pet IndiVideo
**Client**: Nationwide
**Reference recording**: SharePoint — "NW-002 Pet - storyboards & data review-20241223_140659" (request access from Warren Tang)
**Reference BRD**: SharePoint — "NW-002 Pet IndiVideo BRD v1.1 - 2024 01 05.docx"

---

## TL;DR

Nationwide currently ships pet-insurance recipient data files to Bluerush, where **Shaun Ito** (single point of failure) manually filters and reshapes them in Excel before they're uploaded to the IndiVideo Portal for a video email campaign. Bluerush has accepted a scope expansion to **automate** Shaun's pipeline. Two hard constraints: **all data manipulation must happen on US soil**, and the new drop location must be viable for low-to-medium-tech operators on the client side.

---

## Why This Exists

- Shaun Ito at Nationwide is the **only** person who runs the data manipulation today.
- If Shaun moves on, the licence for the existing video pipeline is at risk.
- Bluerush takes over → eliminates the key-person dependency on Nationwide's side, but creates a corresponding vendor liability for Bluerush.

This is a key-person-risk / [[concepts/data-residency]] story as much as a data-pipeline story.

---

## Current Manual Process (Shaun's flow)

1. Receives data files from Nationwide IT (usually 2 files, identical column order)
2. Runs a defined sequence of Excel manipulations
3. Copies the final list into a master list of all previously-created recipients
4. Uploads the file via the IndiVideo Portal
5. Sends a separate file to the email campaign provider with full PURLs

Files contain Nationwide clients reaching the **6-month mark** since their insurance started.

---

## Target Automated Pipeline (Bluerush)

1. **US-based drop location** — set up + train the client on it.
2. **Data manipulation** (run automatically when a file arrives):
   1. Delete row 1–2 and column A (per file, separately)
   2. Filter rows:
      - Remove blank "Insured Email Address"
      - Keep only applicable plans (see Eligible Plans table below)
      - Remove CA MM and WP non-renewals
      - Keep "Pet Species" of "Canine" or "Feline" only
      - Remove rows where "Age" > 30
   3. Add columns:
      - **`Unique ID`** = `Insured code` + `Policy number`
      - **`Statement Date`** = file date parsed from filename (e.g. `New Marketing Report-2025-01-13-11-52-21.xlsx`)
   4. Modify values:
      - Populate Wellness for POIA and VBW plans (only if not already displaying)
      - Coerce types: Number on `Deductible`, `Claimed Amount`, `Claimed Paid Amount`; General on `Co Payment`
      - Title-case `Insured First Name`
   5. Remove columns — **MORE INFO REQUIRED**
   6. Final check:
      - `Unique ID` is unique within the file
      - Compare against master list — drop any duplicate `Unique ID` (master list is source of truth, except permit annual refresh)
3. **Create recipients** via batch upload to the IndiVideo Portal
4. **Maintain master list** by appending new batch rows
5. **Send back to Shaun** a fully-populated file with the unique production PURL per recipient

---

## Eligible Plans

For the last year these have been **Major Medical**, **POIB**, and **MPP non-wellness** plans:

| Base product code | Schedule | Display name |
|---|---|---|
| GMM250T, MM100T, MM250T, MM100, MM1000, MM1000T, MM250, MM500, MM500T | BS | Major Medical |
| POIB25050L, POIB25070L, POIB25090L | POI | Whole Pet |
| VB25050, VB25070, VB25090 | POI | My Pet Protection |
| POIA10050, POIA10070, POIA10090, POIA25090 | (Wellness) | Whole Pet with Wellness |
| VBWL525050, VBWL525070 | (Wellness) | My Pet Protection with Wellness |

(Source spec contains a typo on `VBWL525070` — listed as "My Pet Protection with Wellnes". Carry forward as-is; flag in implementation review.)

---

## Open Items

- **More info required**: which columns to remove in step 2.5
- **Drop location** not yet established — decision pending; must be US-soil
- **Annual refresh allowance** in the dedup logic needs a precise rule (e.g. allow re-creation if `Statement Date` differs by >12 months)
- The source spec embeds two **"We couldn't load the file"** errors — original referenced documents weren't accessible to the LLM; details may need supplementing from the BRD / SharePoint recording

---

## Bluerush Implications

- **Data residency** — see [[concepts/data-residency]]. The pipeline cannot run in `ca-central-1` (Bluerush's primary region); it has to run in a US AWS region. This constrains where the drop bucket, processing compute, and master list storage can live, and changes the [[entities/bluerush]] regional footprint.
- **Vendor liability** — Bluerush replaces Shaun as the bottleneck/single-point-of-failure. Need a runbook for the case where Bluerush operations are unavailable.
- **PII handling** — file contains insured first names + emails + policy data. Standard PII controls apply: encryption at rest (S3 SSE-KMS), encryption in transit (TLS 1.2+), least-privilege IAM, audit logging.

---

## Related Pages

- [[entities/nationwide]], [[entities/bluerush]]
- [[concepts/data-residency]]
- [[concepts/zero-secrets-in-repo]] (any IndiVideo Portal API credentials must come via SSM / Secrets Manager)
