---
title: GitHub Bluerush Account Recovery
category: source
summary: Notes from GitHub Support ticket for recovering or reclaiming the github.com/bluerush organization account.
tags: [github, account-recovery, security, bluerush]
sources: 1
updated: 2026-04-24
source_path: chats/github bluerush account recovery.md
source_date: 2026-04
authors: [Nuno Serrenho]
ingested: 2026-04-24
---

# GitHub Bluerush Account Recovery

**Original**: `chats/github bluerush account recovery.md`
**Support ticket**: [#4178948](https://support.github.com/ticket/personal/0/4178948)

---

## TL;DR

The `github.com/bluerush` organization account is inaccessible. Multiple email addresses were tried without success. GitHub's policy: if 2FA is enabled and all recovery factors are lost, the account is permanently inaccessible — no ID verification override. The available remediation is to unlink email addresses from the locked account so they can be reused on a new account.

---

## Emails Tried

`richard@bluerush.ca`, `richard.pineault@bluerush.ca`, `fred@bluerush.ca`, `frederic@bluerush.ca`, `frederic.plouffe@bluerush.ca`, `derek.rosien@bluerush.ca` (reset succeeded, no orgs), `mike.floyd@bluerush.ca`, `admin@bluerush.ca`, `sysadmin@bluerush.ca`, `bluerush@bluerush.ca`, `eddy@bluerush.ca`, `eddy.malahov@bluerush.ca`

---

## GitHub Account Recovery Policy — Key Points

1. **Automated recovery factors**: verified device, SSH key, or personal access token. Try password reset at `github.com/password_reset` → "Begin account or email recovery".
2. **2FA-locked with no factors**: account is permanently inaccessible. GitHub Support will not restore access via social or ID verification.
3. **Email unlink**: GitHub *can* unlink an email address from a 2FA-locked account so it can be attached to a new account. Requires domain ownership proof. Submit via the support ticket.
4. **What Support cannot do**: transfer repos, restore account contents, social/ID verification bypass.
5. **noreply emails**: cannot be unlinked; commits using noreply addresses cannot be reconnected.

---

## Recommended Next Actions (from ticket)

1. Attempt password reset for each candidate email — check for "Begin account or email recovery" modal.
2. If recovery fails: submit unlink request to GitHub Support with `bluerush.ca` / `bluerush.com` domain ownership proof.
3. Once email is unlinked: create or claim a new `@bluerush` account.

---

## Status

As of 2026-04-24: status unknown — ticket open, awaiting resolution.

---

## Related Pages

- [[entities/bluerush]]
