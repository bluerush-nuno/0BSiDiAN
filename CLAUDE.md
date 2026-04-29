---
title: Bluerush Ops Wiki — CLAUDE.md
category: schema
summary: Repository orientation, wiki schema, conventions, and operations for the 0BSiDiAN Obsidian vault
updated: 2026-04-29
---

# Bluerush Ops Wiki — Repository Guide

> **Topic**: SecDevOps — AWS multi-account operations, CI/CD, IaC, DR, scripting standards
> **Tool**: Claude Code maintaining an Obsidian vault as an LLM Wiki (Karpathy-style "second brain")
> **Initialized**: 2026-04-24

This file is both **repo orientation** for AI assistants and the **wiki schema**. Read it before doing anything else in this repository.

---

## What this repo is

An [Obsidian](https://obsidian.md) vault that doubles as an LLM-maintained knowledge base. Source documents (SOPs, framework specs, chat exports, daily notes) live under `Projects/`, `chats/`, `_notes_/`, `docs/`, and `lost+found/`. The LLM reads them, then incrementally builds and maintains a cross-linked wiki under `wiki/`. Knowledge **compounds** across sessions instead of being re-derived from RAG every query.

Inspired by [Andrej Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). Implemented via the `llm-wiki` skill bundled in `.claude/skills/`.

---

## Repository layout

```
0BSiDiAN/
├── CLAUDE.md            # This file — schema + orientation
├── .claude/
│   └── skills/
│       ├── llm-wiki/                    # Wiki maintainer skill (commands, agents, scripts)
│       └── SecDevOps-Ninja.skill/       # SecDevOps advisor persona
├── .obsidian/           # Obsidian app config (do not hand-edit)
│
├── Projects/            # SOURCE — operator-authored project material (immutable)
│   ├── SecDevOps/       # SecDevOps repo framework spec + skill bundle
│   ├── Powershell/      # PowerShell module standards (own CLAUDE.md inside)
│   ├── IV.Tools.NW/     # NW-002 specs
│   └── TDKC/            # TDKC environments doc
│
├── chats/               # SOURCE — chat exports (DR SOP, account recovery, etc.)
├── _notes_/             # SOURCE — operator daily notes
├── docs/                # SOURCE — misc docs
├── lost+found/          # SOURCE — stray files awaiting triage
│
└── wiki/                # OUTPUT — LLM-owned knowledge base
    ├── index.md         # Content catalog — updated every ingest
    ├── log.md           # Append-only timeline
    ├── entities/        # People, orgs, places, products, tools
    ├── concepts/        # Ideas, principles, frameworks
    ├── sources/         # One summary page per ingested source
    ├── comparisons/     # Cross-source analysis (created on demand)
    └── synthesis/       # High-level overviews and theses
```

### The three layers

| Layer | Path | Who writes | Notes |
|---|---|---|---|
| **Sources** | `Projects/`, `chats/`, `_notes_/`, `docs/`, `lost+found/` | Operator only | **Immutable** — LLM reads, never writes |
| **Wiki** | `wiki/` | LLM | Created, updated, cross-referenced by Claude |
| **Schema** | `CLAUDE.md` (this file) | Co-evolved | Conventions and operations |

---

## Current vault state (as of 2026-04-29)

Always read `wiki/index.md` first to discover what exists before creating new pages — this snapshot can drift.

- **3 sources ingested** (see `wiki/index.md` for the live catalog and `wiki/log.md` for the timeline):
  - `sources/secdevops-repo-framework` — Monorepo layout, security guardrails, scripting standards
  - `sources/web-app-dr-sop` — Windows EC2 + RDS MySQL + S3 DR SOP (ca-central-1)
  - `sources/github-account-recovery` — github.com/bluerush org recovery
- **5 entities**: bluerush, jenkins, opentofu, ansible, aws-organizations
- **9 concepts**: everything-as-code, zero-secrets-in-repo, blast-radius-management, pre-commit-gating, sts-assume-role-pattern, directory-based-env-isolation, trunk-based-development, disaster-recovery, rds-point-in-time-restore
- **2 syntheses**: secdevops-posture, dr-and-resilience-strategy

---

## Operations (slash commands)

Provided by the `llm-wiki` skill at `.claude/skills/llm-wiki/`.

### `/wiki-ingest <path>`
1. Read the source directly from `Projects/`, `chats/`, etc.
2. Discuss with the user — TL;DR, key claims, which pages will be touched, contradictions
3. Wait for confirmation
4. Create or merge the summary page at `wiki/sources/<slug>.md`
5. Update every relevant entity and concept page (typically 5–15 pages)
6. Flag contradictions with `> Warning: Contradiction:` callouts on **both** sides
7. Update `wiki/index.md`
8. Append to `wiki/log.md`: `## [YYYY-MM-DD] ingest | <title>`
9. Report touched pages back to the user

### `/wiki-query <question>`
1. Read `wiki/index.md` first
2. Pick 3–10 relevant pages across categories
3. Read them in full; follow `[[wikilinks]]` opportunistically
4. Synthesize with inline `[[wikilinks]]` citations
5. Offer to file the answer back as a new page in `comparisons/` or `synthesis/`

### `/wiki-lint`
1. Find orphan pages (no inbound links), stale claims, concepts mentioned without their own page
2. Check for contradictions between source pages
3. Verify `index.md` is complete
4. Present findings as a list with suggested actions
5. Append a `lint` entry to `log.md`

### `/wiki-init`, `/wiki-log`
- `/wiki-init` — bootstrap fresh schema (already run; do not re-run without intent)
- `/wiki-log` — show recent log entries

---

## Page frontmatter (required on every wiki page)

```yaml
---
title: <Title>
category: entity | concept | source | comparison | synthesis
summary: <one-line summary>
tags: [tag1, tag2]
sources: <count of sources referencing this page>
updated: YYYY-MM-DD
---
```

For `source` pages also include:
```yaml
source_path: <relative path to original>
source_date: YYYY-MM
authors: [author1]
ingested: YYYY-MM-DD
```

Page templates live at `.claude/skills/llm-wiki/assets/page-templates/`.

---

## Iron rules

1. **Source files are immutable.** Read from `Projects/`, `chats/`, `_notes_/`, `docs/`, `lost+found/`; never write to them. If a source is wrong, the operator fixes it and re-ingests.
2. **All LLM writes go to `wiki/`.** No exceptions.
3. **Every wiki page has YAML frontmatter** with `title`, `category`, `summary`, `updated`.
4. **Every ingest touches ≥5 files.** Source summary, 2–4 entity/concept pages, `index.md`, `log.md`.
5. **Every claim has a citation** — link back to its `sources/<slug>` page.
6. **Contradictions get flagged inline** on both pages with a `> Warning:` callout.
7. **Good answers get filed back.** Explorations compound into `comparisons/` or `synthesis/`.
8. **Update `updated:` frontmatter** whenever you touch a page.

---

## Operator scripting preference

> Use **PowerShell 7 (`pwsh`) and the AWS Tools for PowerShell modular SDK** for everything when interacting with the OS/shell or AWS APIs. Avoid the `aws` CLI and bash where PowerShell can do the job.

- Use `AWS.Tools.*` modular modules, not the monolithic `AWSPowerShell`
- Always pass `-Region` and `-ProfileName` explicitly
- Multi-account: `Get-ORGAccountList` + `Use-STSRole` + `Set-AWSCredential`
- Pass objects through pipelines; use `ConvertTo-Json` / `ConvertFrom-Json` at boundaries
- Deeper PowerShell module conventions live in `Projects/Powershell/CLAUDE.md` — only relevant when working inside an actual PowerShell module project, not the wiki itself

---

## Skills available

Loaded from `.claude/skills/`:

| Skill | When to use |
|---|---|
| `llm-wiki` | All wiki maintenance — ingest, query, lint. Triggered by the `/wiki-*` commands above. |
| `SecDevOps-Ninja.skill` | AWS posture review, IAM audit, secrets management, IaC tooling decisions, CI/CD, IR runbooks. Trigger aggressively for any infra/security/ops question. |

The `llm-wiki` skill ships sub-agents (`wiki-ingestor`, `wiki-linter`, `wiki-librarian`) and Python helper scripts (stdlib only) under `.claude/skills/llm-wiki/scripts/` — `init_vault.py`, `ingest_source.py`, `update_index.py`, `append_log.py`, `wiki_search.py`, `lint_wiki.py`, `graph_analyzer.py`, `export_marp.py`.

---

## Log format

`wiki/log.md` is append-only. Entry format:

```
## [YYYY-MM-DD] <op> | <title>
<optional detail line listing touched pages>
```

Valid ops: `ingest`, `query`, `lint`, `create`, `update`, `delete`, `note`.

---

## Style

- **Concise.** Wiki pages are read by humans, not generated for show.
- **Short paragraphs**, bulleted lists where appropriate.
- **Cite aggressively** with `[[wikilinks]]`.
- **When unsure, say so.** Do not invent content.
- **Lead with the answer.** Context follows, never precedes (per the SecDevOps-Ninja communication rules).
- **No emojis** in wiki pages unless the operator explicitly asks.

---

## Git workflow

This repository is git-tracked. Trunk-based: short-lived branches off `main`, PR required even when working solo. AI-driven work uses the convention `claude/<slug>` (e.g. `claude/add-claude-documentation-Ou4uN`); manual work uses `feature/<slug>` or `fix/<slug>`.

When committing wiki changes, group them by ingest/query/lint operation so the `log.md` entry and the commit map 1:1.

---

## Quick orientation for a new session

1. Read this file (`CLAUDE.md`).
2. Read `wiki/index.md` to see what's been ingested.
3. Read `wiki/log.md` to see recent activity.
4. If the operator asks a question, prefer `/wiki-query`. If they hand over a new doc, use `/wiki-ingest`. If things feel stale, suggest `/wiki-lint`.
