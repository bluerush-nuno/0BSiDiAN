---
title: Nationwide
category: entity
summary: US insurer; Bluerush client for the NW-002 Pet IndiVideo project. Currently relies on Shaun Ito for manual data preparation — Bluerush is taking over to remove that key-person dependency.
tags: [client, nationwide, insurance, vendor, us]
sources: 1
updated: 2026-04-29
---

# Nationwide

**Type**: US insurance company; Bluerush client
**Project of record**: NW-002 Pet IndiVideo (see [[sources/nw-002-pet-data-automation]])
**Geography**: United States — all NW data must be handled on US soil

---

## Project Context

Nationwide ships pet-insurance recipient data to Bluerush, which is then loaded into the IndiVideo Portal to drive a personalized video email campaign at the 6-month policy mark.

### Current state
- **Shaun Ito** (Nationwide) is the sole human handling data preparation
- Manual Excel manipulation, then upload to the IndiVideo Portal
- **Key-person risk** — if Shaun moves on, the project is exposed

### Target state
- Bluerush takes over the data manipulation and runs it on automated infrastructure in a US AWS region
- Client-side workflow becomes "drop a file in a known location"

## Hard Constraints

- **US soil only** — all storage and processing of Nationwide data must happen in the US. This blocks `ca-central-1` (Bluerush's primary region) for this workload — see [[concepts/data-residency]].
- **Low/medium tech tolerance on the client** — the drop mechanism has to be operable by non-engineers.

## Internal Contacts

- **Shaun Ito** (Nationwide) — current data owner
- **Warren Tang** (Bluerush) — holds access to the SharePoint recording of Shaun's process

## Related Pages

- [[sources/nw-002-pet-data-automation]]
- [[entities/bluerush]]
- [[concepts/data-residency]]
