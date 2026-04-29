---
title: Scaffold Templating
category: concept
summary: Project scaffolds are spawned from a GitHub Template Repository plus a local bootstrap script that replaces placeholders, generates a fresh GUID, and runs git init — chosen over branches/forks/Plaster/Catesta for solo-operator simplicity.
tags: [scaffold, templating, github, powershell, conventions]
sources: 1
updated: 2026-04-29
---

# Scaffold Templating

How Bluerush spawns new project repos. The pattern is **template repo + bootstrap script**, optimized for a solo operator who needs zero dependencies and full transparency.

---

## The Pattern

1. **Template repo** — a GitHub repository marked as a **Template Repository** (Settings → Template repository checkbox).
2. **Placeholders** — files contain literal tokens like `{{ModuleName}}`, `{{ModuleGuid}}`, `{{Author}}`, `{{Year}}`.
3. **Bootstrapper** (`tools/bootstrap.ps1`) — prompts for values, replaces tokens, generates a fresh GUID, renames files, optionally wires hub dependencies, runs `git init` + initial commit, optionally creates the GitHub remote, and self-deletes.

See [[sources/ps-module-template-plan]] for the full bootstrap contract.

## Why Not Alternatives

| Alternative | Killed by |
|---|---|
| Branches | History pollution; template-update merges are painful |
| Worktrees | Tied to one repo; no independent project history |
| Forks | Public-by-default; visible fork network; cherry-pick burden |
| Plaster | XML `plasterManifest.xml` overhead without payoff at solo scale |
| Catesta | Same overhead — appropriate when templates are published externally |

## Why It Works

- **Independence** — spawned projects have no upstream link; they diverge intentionally
- **Transparency** — entire templating logic is one PowerShell file in the template
- **Zero deps** — no Plaster/Catesta install required
- **Version traceability** — bootstrap writes `# Scaffolded from PSModuleTemplate vX.Y.Z` into the generated `CLAUDE.md`

## Cross-Cutting Updates

When you improve the template, **already-spawned projects don't auto-sync**. Use Claude Code to apply cross-cutting changes:

> Read `plan.md` and `CLAUDE.md`. Apply the following change to all PowerShell module repos in this workspace: \[describe change]. Create a feature branch in each, run tests, report results.

## Migration Path

If the team grows or templates start being consumed externally, migrate `bootstrap.ps1` → Catesta `plasterManifest.xml`. Catesta handles edge cases (encoding, conditional includes, user prompts) that bootstrap.ps1 deliberately skips.

## See Also

- [[sources/ps-module-template-plan]], [[sources/pscodebase-scaffold]]
- [[entities/psmoduletemplate]]
- [[concepts/public-private-module-split]], [[concepts/explicit-module-exports]]
- [[concepts/everything-as-code]]
