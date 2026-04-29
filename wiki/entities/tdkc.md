---
title: TDKC (TD Knowledge Centre)
category: entity
summary: Bluerush-hosted TD Knowledge Centre web app (td-digitalreach-html) — Tomcat 8.5 on Windows EC2 with dedicated RDS MySQL 8 in ca-central-1; the production target referenced by the DR SOP.
tags: [tdkc, td, project, tomcat, rds-mysql, windows, ca-central-1]
sources: 2
updated: 2026-04-29
---

# TDKC — TD Knowledge Centre

**Type**: Bluerush-hosted client web property
**Project codename**: `td-digitalreach-html`
**Public URL (staging)**: <https://td.bluerush.ca/external/>
**Region**: `ca-central-1`

---

## Stack

- **Web tier**: Tomcat 8.5 on Windows Server EC2 (2x prod, 1x staging)
- **DB**: AWS RDS MySQL 8 — staging shares multi-tenant `mysql8-td-rds`; prod has dedicated `mysql8-tdkc-rds`
- **Hosts**:
  - Prod: `host1a-tdkc` (ca-central-1a), `host1b-tdkc` (ca-central-1b)
  - Staging: `stage1b-tdkc`
- **DNS**: `*.aws.bluerush.com`
- **Disk layout**: `C:\bluerush\hosting\td-digitalreach-html\tomcat85\` (prod) / `…-stage\` (staging)

Full environment reference: [[sources/tdkc-environments]].

## Operational Conventions

- **Stage-first deployment** — see [[concepts/stage-first-deployment]]. No ad-hoc prod changes; everything validated in staging, then packaged (ZIP for files, explicit SQL for DB).
- **Disk sync** — staging `conf/`, `ROOT/`, `media/`, `convert/` are kept in sync with prod, so promotion is reproducible.
- **Common change targets**: `ROOT\branding\`, `ROOT\email\`.

## Cross-Refs

- The DR SOP ([[sources/web-app-dr-sop]]) runbooks against this exact stack — `host1a-tdkc` / `host1b-tdkc` and `prod-db` ≈ `mysql8-tdkc-rds`.
- The TD WEB shared RDS (`mysql8-td-rds`) is multi-tenant — staging schemas for several TD properties share that instance.

## Open Hardening Items

- DB connections use `useSSL=false` (unencrypted Tomcat ↔ RDS within VPC). See [[sources/tdkc-environments]] for mitigation notes.
- Tomcat `server.xml` carries static DB credentials — not yet migrated to [[concepts/zero-secrets-in-repo]] / SSM pattern.
- RDP host `stage1b-tdkc.aws.bluerush.com` should be confirmed as VPN-only.

## Related Pages

- [[sources/tdkc-environments]], [[sources/web-app-dr-sop]]
- [[entities/bluerush]], [[entities/aws-organizations]]
- [[concepts/stage-first-deployment]], [[concepts/directory-based-env-isolation]]
- [[concepts/disaster-recovery]], [[concepts/rds-point-in-time-restore]]
- [[synthesis/dr-and-resilience-strategy]]
