## Context

The agenda priority tiers live in `config.org` (literate; tangles to `config.el`). Each tier is an org tag (`on_fire`, `bells_ringing`, `on_deck`, `recently_considered`) toggled by a single agenda key (`f`/`b`/`d`/`c`) via four near-identical `tdw/agenda-toggle-*` commands (~lines 2038–2253). Each toggle adds/removes only its own tag — so tiers can stack — and performs an in-place update of the per-task prefix annotation in two render styles: the Ordered View (`… U:xx I:xx [nn]`) and the Unordered View (`🔥 U:xx I:xx`).

Tier membership decides which **block** a task appears in within the tiered views (Ordered ~2347, Unordered ~2504, Someday Priority ~1660); block order top-to-bottom is the ladder, and each tier's header shows an effort total for its tasks.

A close precedent already exists: `tdw/agenda-cycle-tag` (~1967) maintains a mutually-exclusive set of level tags (urgency/impact) by removing the old sibling and adding the new one.

## Goals / Non-Goals

**Goals:**
- Make the five tiers mutually exclusive (radio): at most one tier per task; re-selecting the active tier clears to none.
- Add a Paused tier (`paused`, `🕐`, key `p`) as the lowest rung, displayed last among tier blocks in every view, with an effort total in its header like the other tiers.
- Collapse the four duplicated toggle commands into one shared command driven by a single ordered source-of-truth list of tier tags.
- Preserve the single-keypress UX and every existing non-tier binding.

**Non-Goals:**
- Data-driving the large quasiquoted agenda block forms from the tag list — the block definitions stay explicit; only the paused block is added.
- Rebinding any existing key (`r` stays refresh, `c` stays recently-considered).
- Changing how "nothing"/untiered tasks are displayed.

## Decisions

**1. One `tdw/agenda-set-tier` command + one `tdw--tier-tags` list.**
A single command clears every tier tag in the ordered list `tdw--tier-tags` = `(on_fire bells_ringing on_deck recently_considered paused)`, then applies the requested one (or leaves it cleared — see #2), recomputes the score tag, and runs the existing in-place prefix update. `f`/`b`/`d`/`c`/`p` become thin bindings to it. *Why:* eliminates four-way duplication and tag drift; the list becomes the single place that enumerates tiers. *Alternative considered:* keep four commands and add "clear the others" to each — rejected, multiplies the duplication and the drift risk the consolidation is meant to remove. *Precedent:* `tdw/agenda-cycle-tag`.

**2. Re-pressing the active tier clears to "nothing" (at-most-one, not exactly-one).**
*Why:* untiered is the common resting state and must stay reachable; reusing the same key to clear is the natural gesture and matches today's toggle-off muscle memory. *Alternative:* a separate "clear tier" key — rejected as an extra binding for no benefit.

**3. Paused glyph = single `🕐` (U+1F550); header not doubled.**
*Why:* verified East-Asian-Width Wide — the same class as the working `🔥`/`🔔`/`🥎`/`💭` and the prior `⚾→🥎` redraw fix. The tempting clock alternatives `⏸` (U+23F8) and `🕰` (U+1F570) measure Narrow and are exactly the ambiguous-width shape that previously caused terminal redraw corruption. Single (not doubled) per user preference; the per-task prefix `🕐 ` matches the existing single-glyph prefix convention.

**4. Paused block is the last of the five contiguous tier blocks.**
*Why:* "lowest rung" in the ladder. The tier blocks sit together at the top of each view in highest→lowest order; Paused extends that downward, right after Recently Considered.

**5. Block forms stay explicit; only the tag list + command are centralized.**
*Why:* the quasiquoted view definitions are working code; generating them from `tdw--tier-tags` is a larger, riskier rewrite than this change warrants. Centralizing the tag list and the set-tier logic captures most of the de-duplication benefit at a fraction of the blast radius.

**6. The Paused header shows an effort total, like the other tiers.**
The `🕐 Paused` section header displays the summed effort of its tasks, consistent with `🔥🔥 On Fire (…)` and siblings. *Why:* parity with the other tiers and a quick read of how much parked work has accumulated. *Implementation reach:* this is the one decision that touches the header machinery — the header-detection regex list (~1075), the per-tier effort updater (~1099–1114), and the effort/count alist (~1030–1052) all gain a Paused entry.

## Risks / Trade-offs

- **`🕐` causes terminal/daemon redraw corruption** → Verify the glyph live in the real terminal+Emacs before committing; formal Unicode width did not predict the `⚾` breakage, so rendering is the only trustworthy test.
- **Behavior change: tiers no longer stack** → Intended improvement, but breaks any habit relying on stacking; call it out in the commit message. Any task that currently has multiple tier tags is normalized to one on the next `set-tier` press.
- **Factoring out the in-place prefix update could regress one render style** → Reuse the existing Ordered-View (`U:xx I:xx [nn]`) and Unordered-View (`🔥 U:xx I:xx`) regexes verbatim in the shared helper; verify both views still update in place after a tier change.
- **Effort-total plumbing spans three sites** → The header regex, per-tier effort updater, and effort/count alist must all learn the Paused header in lockstep, or the total renders stale or not at all; verify the Paused header total after adding a paused task.
- **Forgetting to re-tangle** → `config.el` is generated from `config.org`; the change is inert until re-tangled. Make re-tangle an explicit, verified step.
