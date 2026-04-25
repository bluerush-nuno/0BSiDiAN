# TDKC DigitalReach — Environment Reference

> **Project:** TD Knowledge Centre (`td-digitalreach-html`)
> **Platform:** AWS EC2 (Windows) + AWS RDS MySQL 8 — `ca-central-1`

---

## Staging Environment

### Access

| Type | Value |
|------|-------|
| RDP Host | `stage1b-tdkc.aws.bluerush.com` |
| App URL | https://td.bluerush.ca/external/ |

### Filesystem Paths

| Component | Path |
|-----------|------|
| Tomcat root | `C:\bluerush\hosting\td-digitalreach-html-stage\tomcat85\` |
| DB config (`server.xml`) | `C:\bluerush\hosting\td-digitalreach-html-stage\tomcat85\conf\server.xml` |
| Frontend (`ROOT`) | `C:\bluerush\hosting\td-digitalreach-html-stage\tomcat85\webapps\ROOT\` |

### Database — AWS RDS MySQL 8 (shared TD WEB RDS)

| Property | Value |
|----------|-------|
| Host | `mysql8-td-rds.clgyqom42adb.ca-central-1.rds.amazonaws.com` |
| Port | `3306` |
| Schema | `tdkc_digitalreach_uat` |
| User | `tdkc_uat_dbuser` |
| Password | `a…` *(redacted — see server.xml)* |

**JDBC URL:**
```
mysql8-td-rds.clgyqom42adb.ca-central-1.rds.amazonaws.com:3306/tdkc_digitalreach_uat
  ?useUnicode=true&characterEncoding=UTF-8&useSSL=false&useTimezone=true&serverTimezone=US/Eastern
```

> ⚠️ **Note:** Active data in staging only goes back to **2025-01**. Users with known activity: Fred, Debby, Yaroslav, QA.

---

## Production Environment

### Access

| Type | Value |
|------|-------|
| RDP Host A | `host1a-tdkc.aws.bluerush.com` |
| RDP Host B | `host1b-tdkc.aws.bluerush.com` |

> ℹ️ Direct prod RDP access is **not required** for deployments — see [Deployment Workflow](#deployment-workflow) below.

### Filesystem Paths

| Component | Path |
|-----------|------|
| Tomcat root | `C:\bluerush\hosting\td-digitalreach-html\tomcat85\` |
| DB config (`server.xml`) | `C:\bluerush\hosting\td-digitalreach-html\tomcat85\conf\server.xml` |
| Frontend (`ROOT`) | `C:\bluerush\hosting\td-digitalreach-html\tomcat85\webapps\ROOT\` |

> ℹ️ The staging disk folders are **kept in sync** with the prod EC2 instances for the following directories: `conf`, `ROOT`, `media`, `convert`.

### Database — AWS RDS MySQL 8 (dedicated TDKC PROD RDS)

| Property | Value |
|----------|-------|
| Host | `mysql8-tdkc-rds.clgyqom42adb.ca-central-1.rds.amazonaws.com` |
| Port | `3306` |
| Schema | `tdkc_prod` |
| User | `tdkc_dbuser` |
| Password | `q…` *(redacted — see server.xml)* |

**JDBC URL:**
```
mysql8-tdkc-rds.clgyqom42adb.ca-central-1.rds.amazonaws.com:3306/tdkc_prod
  ?useUnicode=true&characterEncoding=UTF-8&useSSL=false&useTimezone=true&serverTimezone=US/Eastern
```

---

## Deployment Workflow

1. **Stage first** — make and validate all changes in staging before touching prod.
2. **Replicate** — identify which tables/rows need to be promoted; provide rationale.
3. **Package changes** — all deployments to prod must use:
   - ZIP packages for filesystem changes
   - Explicit `INSERT` / `UPDATE` / `ALTER` SQL statements for DB changes
4. **Key directories** for most changes: `ROOT\branding\` and `ROOT\email\`

> 🚫 **No ad-hoc changes directly in PROD.**

---

## Quick Reference — Environment Comparison

| | Staging | Production |
|-|---------|------------|
| RDP | `stage1b-tdkc.aws.bluerush.com` | `host1a/1b-tdkc.aws.bluerush.com` |
| Tomcat base | `td-digitalreach-html-stage` | `td-digitalreach-html` |
| RDS instance | `mysql8-td-rds` (shared) | `mysql8-tdkc-rds` (dedicated) |
| Schema | `tdkc_digitalreach_uat` | `tdkc_prod` |
| DB user | `tdkc_uat_dbuser` | `tdkc_dbuser` |
