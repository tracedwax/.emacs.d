## Why

The org-agenda priority tiers (On Fire / Bells Ringing / On Deck / Recently Considered) are implemented as four independent toggles, so a task can carry several tier tags at once. "Stacking" muddies which rung a task actually sits on and makes downgrading a manual two-step (remove the old tag, add the new). There is also no way to deliberately set a task aside — to park it below everything else — without stripping its tier. This change turns the tiers into a single ladder (exactly one rung at a time) and adds a **Paused** rung at the bottom for parked work.

## What Changes

- **BREAKING (behavior):** Priority tiers become **mutually exclusive** (radio). Pressing a tier key sets that tier and clears the other four; pressing the key of the tier a task already has clears it back to no tier. Tiers no longer stack.
- New **Paused** tier — tag `paused`, section header `🕐 Paused` (single clock glyph), bound to `p` — added as the **lowest rung** of the ladder. Its block is the last of the tier blocks in every agenda view, and its header shows an effort total like the other tiers.
- The four near-identical tier-toggle commands are consolidated into **one** shared "set tier" command driven by a single ordered list of tier tags (one source of truth, mirroring the existing urgency/impact cycling pattern).
- Keys: `f`/`b`/`d`/`c` keep their current bindings (now "set" rather than "toggle"); `p` is newly bound (today it falls through to a stock `previous-line` binding that is redundant with `k`). Nothing else moves — `r` stays refresh, `c` stays recently-considered.

## Capabilities

### New Capabilities
- `agenda-priority-tiers`: The manual priority-tier layer on top of org-agenda — the set of tiers and their order, the mutually-exclusive (radio) selection behavior including the new Paused rung, the single key that sets each tier, and how tiered tasks are grouped and ordered (tier-first, with per-tier effort totals) in the agenda views.

### Modified Capabilities
<!-- None. openspec/specs/ is empty — this is the first captured capability. -->

## Impact

- **Code:** `config.org` only (literate config — **must re-tangle to `config.el`**). Touchpoints:
  - Tier commands (~2038–2253) → consolidated into one `tdw/agenda-set-tier`; new `tdw--tier-tags` source-of-truth defvar.
  - Key bindings in the `with-eval-after-load 'org-agenda` block (~1540): `f`/`b`/`d`/`c` repointed to the shared command; new `p` binding.
  - Per-task emoji prefix resolvers `org-gtd-agenda--resolve-score` (~1598) and `--resolve-urg-imp` (~1628): add `paused → "🕐 "`.
  - Tier-block definitions in the two block-bearing views — Unordered (~2506–2541) and Someday Priority (~1662–1686): add the Paused block as the last tier block. (The Ordered View / `org-gtd-engage` shows tiers as inline prefix glyphs, not blocks, so it needs only the `🕐` prefix.)
  - Effort-total plumbing for the Paused header: header-detection regex (~1075), per-tier effort updater (~1099–1114), effort/count alist (~1030–1052).
  - `tdw--excluded-tag-prefixes` (~1184): add `paused`.
- **Data:** introduces a `:paused:` org tag on tasks; existing tier tags unchanged.
- **Risk:** the `🕐` glyph must render without terminal/daemon redraw corruption — verify live before committing (prior ambiguous-width emoji caused corruption); plus the deliberate behavior change for any habit that relied on stacking tiers.
