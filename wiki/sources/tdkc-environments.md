---
title: TDKC DigitalReach — Environment Reference
category: source
summary: Staging vs production environment reference for the td-digitalreach-html app — Tomcat 8.5 on Windows EC2, RDS MySQL 8 in ca-central-1, stage-first deployment workflow.
tags: [tdkc, td, environments, tomcat, rds, mysql, ca-central-1, windows, deployment]
sources: 1
updated: 2026-04-29
source_path: Projects/TDKC/tdkc-environments.md
source_date: 2026-04
authors: [Nuno Serrenho]
ingested: 2026-04-29
---

# TDKC DigitalReach — Environment Reference

**Original**: `Projects/TDKC/tdkc-environments.md`
**Project**: `td-digitalreach-html` (TD Knowledge Centre)
**Platform**: AWS EC2 Windows + RDS MySQL 8 — `ca-central-1`

---

## TL;DR

Reference card for the TDKC web property's two environments (staging, production). Both run Tomcat 8.5 on Windows Server EC2 in `ca-central-1`. Staging shares a multi-tenant RDS instance; prod has a dedicated RDS. Deployment is **stage-first** — all changes validated in staging before being packaged (ZIP for files, explicit DDL/DML for DB) and applied to prod. No ad-hoc prod changes.

The TDKC EC2 hosts (`host1a-tdkc`, `host1b-tdkc`) are the same hosts referenced in [[sources/web-app-dr-sop]] — TDKC is the production property that DR SOP runbooks restore.

---

## Staging

| Property | Value |
|----------|-------|
| RDP host | `stage1b-tdkc.aws.bluerush.com` |
| App URL | <https://td.bluerush.ca/external/> |
| Tomcat root | `C:\bluerush\hosting\td-digitalreach-html-stage\tomcat85\` |
| `server.xml` | `…\conf\server.xml` |
| Frontend | `…\webapps\ROOT\` |
| RDS host | `mysql8-td-rds.clgyqom42adb.ca-central-1.rds.amazonaws.com` (shared TD WEB RDS) |
| Schema | `tdkc_digitalreach_uat` |
| User | `tdkc_uat_dbuser` |

> **Data window**: staging only contains active data back to **2025-01**. Known active users: Fred, Debby, Yaroslav, QA.

## Production

| Property | Value |
|----------|-------|
| RDP host A | `host1a-tdkc.aws.bluerush.com` (ca-central-1a) |
| RDP host B | `host1b-tdkc.aws.bluerush.com` (ca-central-1b) |
| Tomcat root | `C:\bluerush\hosting\td-digitalreach-html\tomcat85\` |
| `server.xml` | `…\conf\server.xml` |
| Frontend | `…\webapps\ROOT\` |
| RDS host | `mysql8-tdkc-rds.clgyqom42adb.ca-central-1.rds.amazonaws.com` (dedicated TDKC PROD RDS) |
| Schema | `tdkc_prod` |
| User | `tdkc_dbuser` |

> Direct prod RDP is **not required** for deployments — see Deployment Workflow.
> Staging disk folders (`conf`, `ROOT`, `media`, `convert`) are **kept in sync** with prod.

## Quick comparison

| | Staging | Production |
|-|---------|------------|
| RDP | `stage1b-tdkc` | `host1a/1b-tdkc` |
| Tomcat base | `td-digitalreach-html-stage` | `td-digitalreach-html` |
| RDS | `mysql8-td-rds` (shared multi-tenant) | `mysql8-tdkc-rds` (dedicated) |
| Schema | `tdkc_digitalreach_uat` | `tdkc_prod` |
| DB user | `tdkc_uat_dbuser` | `tdkc_dbuser` |

---

## Deployment Workflow

1. **Stage first** — make and validate every change in staging before touching prod.
2. **Replicate** — identify which tables/rows need to be promoted; provide rationale.
3. **Package** — prod deployments must use:
   - **ZIP packages** for filesystem changes
   - **Explicit `INSERT` / `UPDATE` / `ALTER`** SQL statements for DB changes
4. Most changes target `ROOT\branding\` and `ROOT\email\`.

> **No ad-hoc changes directly in PROD.**

This codifies [[concepts/stage-first-deployment]].

---

## Security & Risk Notes

- **`useSSL=false` in JDBC URLs** — both staging and prod reference `useSSL=false` in their connection strings. The DB connection is unencrypted between Tomcat and RDS. If they're in the same VPC + SG, the blast radius is bounded, but this is still a hardening gap worth tracking. Mitigation: enable RDS SSL/TLS, add `useSSL=true&requireSSL=true&verifyServerCertificate=true`, install RDS CA bundle into Tomcat's truststore.
- **Static IAM-less DB credentials in `server.xml`** — passwords live in Tomcat config files, not in [[concepts/zero-secrets-in-repo]]-style SSM paths. This is the legacy connection model. A future improvement is to pull DB credentials from SSM at Tomcat startup (e.g., a `setenv.bat` shim that calls `Get-SSMParameterValue`).
- **Direct RDP to staging** is exposed via `stage1b-tdkc.aws.bluerush.com`. Confirm this resolves only inside VPN / internal network; if it's public, push toward SSM Session Manager (per [[concepts/sts-assume-role-pattern]] credential model).

---

## DR Cross-Reference

The DR SOP at [[sources/web-app-dr-sop]] runbooks against the **same hosts** described here:
- `host1a-tdkc` / `host1b-tdkc` — the production EC2 pair
- The `prod-db` RDS in the DR SOP corresponds to the dedicated `mysql8-tdkc-rds`
- The DR SOP's `/prod/database/endpoint` SSM path is the abstraction layer that lets a PITR restore swap endpoints without changing `server.xml` (when the SSM-driven config is implemented — see Security Notes above)

---

## Related Pages

- [[sources/web-app-dr-sop]], [[sources/secdevops-repo-framework]]
- [[entities/tdkc]], [[entities/bluerush]], [[entities/aws-organizations]]
- [[concepts/stage-first-deployment]], [[concepts/directory-based-env-isolation]]
- [[concepts/zero-secrets-in-repo]], [[concepts/disaster-recovery]]
- [[synthesis/dr-and-resilience-strategy]]
