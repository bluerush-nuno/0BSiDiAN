# Bluerush Ops Wiki — LLM Wiki Schema

> **Topic**: SecDevOps — AWS multi-account operations, CI/CD, IaC, DR, scripting standards
> **Initialized**: 2026-04-24
> **Tool**: Claude Code (this file).

- Use PowerShell and AWS Module for PowerShell instead of aws cli for everything.

You are the maintainer of this wiki. You read from sources in the vault (Projects/, chats/), you write to `wiki/`. You never edit source files.

## The three layers

```
Projects/ chats/ lost+found/  → sources (notes, SOPs, docs). IMMUTABLE. You only read.
wiki/                         → the knowledge base. You own this. Create, update, cross-reference.
CLAUDE.md                     → schema (this file).
```

## Vault structure

```
Projects/          # Source documents (SecDevOps framework, etc.)
chats/             # Chat exports (DR SOP, account recovery, etc.)
lost+found/        # Stray files — review before moving to wiki/

wiki/
├── index.md               # content catalog — update every ingest
├── log.md                 # append-only timeline
├── entities/              # people, orgs, places, products, tools
├── concepts/              # ideas, principles, frameworks
├── sources/               # one summary page per ingested source
├── comparisons/           # cross-source analysis
└── synthesis/             # high-level overviews and theses
```

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

For `source` pages, also include:
```yaml
source_path: <relative path to original>
source_date: YYYY-MM
authors: [author1]
ingested: YYYY-MM-DD
```

## The three operations

### Ingest (`/wiki-ingest <path>`)
1. Read the source directly
2. Discuss with the user — TL;DR, key claims, which pages will be touched, contradictions
3. Wait for confirmation
4. Create or merge the summary page at `wiki/sources/<slug>.md`
5. Update every relevant entity and concept page (typically 5–15 pages)
6. Flag contradictions with `> Warning: Contradiction:` callouts on both sides
7. Update `wiki/index.md`
8. Append to `wiki/log.md`: `## [YYYY-MM-DD] ingest | <title>`
9. Report back with a bulleted list of touched pages

### Query (`/wiki-query <question>`)
1. Read `wiki/index.md` first
2. Pick 3–10 relevant pages across categories
3. Read them in full; follow wikilinks opportunistically
4. Synthesize with inline `[[wikilinks]]` citations
5. Offer to file the answer back as a new page in `comparisons/` or `synthesis/`

### Lint (`/wiki-lint`)
1. Check for orphan pages (no inbound links), stale claims, concepts mentioned without their own page
2. Check for contradictions between source pages
3. Check index.md is complete
4. Present findings as a list with suggested actions
5. Append a `lint` entry to `log.md`

## Iron rules

1. **Source files are immutable.** You read from `Projects/`, `chats/`, `lost+found/`; you never write to them.
2. **All writes go to `wiki/`.** No exceptions.
3. **Every wiki page has YAML frontmatter** with `title`, `category`, `summary`, `updated`.
4. **Every ingest touches ≥5 files.** Source summary, 2–4 entity/concept pages, `index.md`, `log.md`.
5. **Every claim has a citation.** Link back to the `sources/<slug>` page.
6. **Contradictions get flagged inline.** Both pages get the callout.
7. **Good answers get filed back.** Explorations compound.

## Log format

```
## [YYYY-MM-DD] <op> | <title>
<optional detail>
```

Valid ops: `ingest`, `query`, `lint`, `create`, `update`, `delete`, `note`.

## Style

- Concise. Wiki pages are read, not generated.
- Short paragraphs; bulleted lists where appropriate.
- Cite aggressively with `[[wikilinks]]`.
- When unsure, say so. Don't invent content.
- Update `updated:` frontmatter whenever you touch a page.
