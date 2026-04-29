---
title: Stage-First Deployment
category: concept
summary: All changes are made and validated in staging before being packaged (ZIP for filesystem, explicit SQL for DB) and applied to prod. No ad-hoc prod changes — staging is the rehearsal, prod is the recital.
tags: [deployment, conventions, change-management, principle]
sources: 1
updated: 2026-04-29
---

# Stage-First Deployment

**Operating rule** for Bluerush-hosted web properties — most explicitly documented for [[entities/tdkc]], applies generally.

> Make and validate **all** changes in staging before touching prod.
> Promote via **packaged artifacts**, never ad-hoc edits.
> **No ad-hoc changes directly in prod.**

---

## The Workflow

1. **Make change in staging.** Edit files, run migrations, modify config — only on the staging environment.
2. **Validate in staging.** Smoke test, regression check, stakeholder review if relevant.
3. **Identify what to promote.** Which files? Which tables/rows? With what rationale?
4. **Package the change.**
   - Filesystem changes → **ZIP** archive (so the unit of promotion is auditable)
   - DB changes → **explicit `INSERT` / `UPDATE` / `ALTER`** statements (no "just sync the schemas")
5. **Apply to prod.** Deploy the package; run the SQL.
6. **Verify in prod.** Match the staging validation steps.

## Why It Works

- **Mistakes are caught in staging**, where blast radius is bounded to test data and the operator's reputation, not customer data.
- **Promotion is reproducible.** The ZIP and the SQL file are the deployment artifacts — they can be reviewed, version-controlled, and replayed.
- **Audit trail is automatic.** Every prod change has a corresponding artifact, not a Tomcat console session.
- **Disaster recovery is easier.** When restoring after an incident, you re-apply the same artifacts — no "oh wait, what was that thing Yaroslav did last Tuesday."

## Disk-Sync Reinforcement

For [[entities/tdkc]] specifically, staging disk folders (`conf/`, `ROOT/`, `media/`, `convert/`) are kept in sync with prod. This means:
- The staging environment is always a faithful clone — promotion is just diff + ZIP.
- After a DR restore, syncing from staging recovers any media that was lost.

## Common Change Targets (TDKC)

- `ROOT\branding\` — visual customizations per partner/audience
- `ROOT\email\` — transactional email templates
- DB rows in lookup/config tables

## Adjacency

This is the runtime/deployment mirror of [[concepts/directory-based-env-isolation]] — that one says "prod and nonprod are separate directories in the source repo"; this one says "prod and staging are separate environments at runtime, with packaged promotion between them." Both close the same class of mistake (accidental cross-environment writes) at different layers.

## See Also

- [[sources/tdkc-environments]]
- [[entities/tdkc]]
- [[concepts/directory-based-env-isolation]]
- [[concepts/blast-radius-management]]
- [[concepts/everything-as-code]]
