---
title: Ansible
category: entity
summary: Ansible is used by Bluerush for EC2 configuration management, CIS hardening, and ad-hoc ops. Dynamic inventory via the aws_ec2 plugin.
tags: [ansible, configuration-management, ec2, cis, aws]
sources: 1
updated: 2026-04-24
---

# Ansible

**Role**: Configuration management, EC2 hardening, ad-hoc operational tasks
**Inventory model**: Dynamic — `aws_ec2` plugin; separate inventory files per environment

---

## Directory Structure (`ansible/`)

```
ansible/
├── ansible.cfg              # Repo-scoped config (roles_path, inventory, etc.)
├── inventories/
│   ├── prod/aws_ec2.yml     # Dynamic inventory for prod
│   └── nonprod/aws_ec2.yml  # Dynamic inventory for nonprod
├── playbooks/
│   ├── ec2-hardening.yml        # CIS Level 1 baseline
│   ├── jenkins-agent-setup.yml
│   ├── rds-maintenance.yml
│   └── _destructive/            # Playbooks with irreversible side effects
│       └── ec2-terminate.yml
└── roles/
    ├── common/          # Applied to every host (syslog, auditd, etc.)
    ├── cis-hardening/   # CIS AWS L1 controls
    ├── aws-ssm-agent/   # Ensure SSM agent installed + running
    ├── cloudwatch-agent/
    └── mysql-client/
```

## Key Playbooks

| Playbook | Purpose |
|----------|---------|
| `ec2-hardening.yml` | CIS L1 baseline hardening — runs `cis-hardening` + `common` roles |
| `jenkins-agent-setup.yml` | Provision Jenkins EC2 agents |
| `rds-maintenance.yml` | Database maintenance tasks |
| `ec2-terminate.yml` | **Destructive** — in `_destructive/`; requires confirmation gate |

## Naming Convention

`<target>-<action>.yml` — e.g., `ec2-hardening.yml`, `rds-snapshot-verify.yml`, `jenkins-agent-provision.yml`.

## Roles Overview

- **`common`**: Applied universally — syslog, auditd, baseline packages.
- **`cis-hardening`**: CIS AWS Foundations Level 1 controls.
- **`aws-ssm-agent`**: Ensures SSM agent is installed and running (required for Session Manager and Parameter Store access).
- **`cloudwatch-agent`**: CloudWatch metrics and log shipping.
- **`mysql-client`**: MySQL CLI client for DB ops tasks.

## Collections

Galaxy collection dependencies tracked in `collections/requirements.yml`.

## Pre-commit Gate

`ansible-lint` runs on all `ansible/.*\.(yml|yaml)$` files via pre-commit. See [[concepts/pre-commit-gating]].

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[entities/bluerush]]
- [[entities/aws-organizations]]
- [[concepts/everything-as-code]]
- [[concepts/blast-radius-management]]
- [[synthesis/secdevops-posture]]
