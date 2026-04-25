---
title: Directory-Based Environment Isolation
category: concept
summary: Production and non-production environments are separated by filesystem directory, never by flags, variables, or branches. Mistakes in one environment cannot bleed into another.
tags: [principle, environments, security, iac, ansible]
sources: 1
updated: 2026-04-24
---

# Directory-Based Environment Isolation

**Design Principle #3** of the Bluerush ops monorepo.

> "Environment isolation is structural — `prod/` and `nonprod/` are sibling directories, never flags/variables."

---

## Where Applied

### IaC (`iac/environments/`)
```
iac/environments/
├── prod/       # Root module for production account
├── nonprod/    # Root module for non-production account
└── mgmt/       # Management/tooling account
```
Each environment has its own `backend.tf` pointing to a separate S3 state bucket + DynamoDB lock table. State is **never shared** across environments.

### Ansible (`ansible/inventories/`)
```
ansible/inventories/
├── prod/
│   ├── aws_ec2.yml        # Dynamic inventory — prod account only
│   └── group_vars/all.yml
└── nonprod/
    ├── aws_ec2.yml        # Dynamic inventory — nonprod account only
    └── group_vars/all.yml
```

### Scripts (`scripts/bash/aws/`, `scripts/pwsh/aws/`)
Environment is passed as an explicit parameter (e.g., `--profile prod-profile`, `$ENV` variable) — never inferred from a default.

## Why Not Flags or Variables?

A flag-based approach (e.g., `ENV=prod ./deploy.sh`) has failure modes:
- Typos silently target the wrong environment.
- Default values can target prod accidentally.
- No filesystem-level barrier; any script can reach any environment.

Directory isolation means:
- You must be in the prod directory to run prod commands.
- CI/CD pipelines explicitly reference the environment directory.
- `tofu plan` in `iac/environments/nonprod/` **cannot** accidentally target prod state.

## Jenkins Enforcement

The `ENVIRONMENT` pipeline parameter (`nonprod` | `prod`) maps directly to `iac/environments/${params.ENVIRONMENT}` — a directory path, not a variable substituted into a flag. Prod additionally requires the `input` gate. See [[entities/jenkins]].

---

## Related Pages

- [[sources/secdevops-repo-framework]]
- [[entities/opentofu]]
- [[entities/ansible]]
- [[entities/aws-organizations]]
- [[concepts/blast-radius-management]]
- [[synthesis/secdevops-posture]]
