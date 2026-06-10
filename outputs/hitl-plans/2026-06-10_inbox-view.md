# HITL Plan: Inbox View for org-gtd config

**Created:** 2026-06-10
**Repo:** `~/.emacs.d` (source of truth: `config.org`; `config.el` is the tangled artifact via `org-babel-load-file`)

---

## Context & Locked Design (from grill-me)

Build a new **Inbox View** that mirrors the existing **Someday View** (`tdw-someday-priority-view`), with one new requirement: a prominent banner on all 4 views.

**Locked decisions:**

- **Marker:** inbox items carry `ORG_GTD="Inbox"` — a true peer to `"Someday"`/`"Actions"`. The view filters `tags-todo` on `ORG_GTD="Inbox"`.
- **Sections:** clone the **Someday** view's section set (tiers On Fire → Bells → On Deck → Recently Considered → Paused → Flyby, Big Rocks, Quick Wins, Other Rocks, Unestimated, Toggl Projects). Identical styling (prefix, effort + urg/imp annotation, hidden tag markers).
- **TODO keyword:** inbox items use the `TODO` keyword so `tags-todo` blocks reliably match them (the view hides the keyword via `org-agenda-todo-keyword-format ""`, so display is unchanged).
- **Banner (style A) on ALL 4 views** (Inbox / Someday / Unordered / Ordered), replacing the current one-line `📋 … View — Total Effort: …` title:
  ```
  ═══════════════════  📥  INBOX VIEW  ═══════════════════
  Total Estimated Effort: 2:15
  ```
  Per-view icons: 📥 Inbox, 💤 Someday, 📋 Unordered, 🎯 Ordered. Distinct face. Second line label is `Total Estimated Effort:` (renamed from `Total Effort`).
- **File:** reuse the existing org-gtd `inbox.org` (`org-gtd-inbox-path`, in `org-gtd-directory`). Add it to `org-agenda-files`.
- **Population:** primarily a future LLM workflow command (singly or en masse) emitting the item-format contract below. `C-c d c i` manual capture kept as a rare fallback, stamping `ORG_GTD="Inbox"`.
- **Item-format contract** (for the LLM workflow):
  ```org
  * TODO <title>                                   :tag1:tag2:
  :PROPERTIES:
  :ORG_GTD:  Inbox
  :CREATED:  [timestamp]
  :END:
  ```
  Only `ORG_GTD: Inbox` is required. Optional: tags (route into tier/Toggl sections), `EFFORT`, `score_NN`, tier tags (`on_fire`…). Bare titled `TODO` items land in "Unestimated".
- **Grooming:** existing `s`/`n`/`x` agenda keys work unchanged — `tdw/agenda-move-to-someday` / `-to-next` read the current `ORG_GTD`, flip it, and refile out of `inbox.org` into `org-gtd-tasks.org`. Inbox empties as it's groomed.
- **Effort-scanner guard:** `tdw/get-sanity-effort-totals` counts NEXT/TODO across all agenda files without filtering `ORG_GTD`, so it must **skip `ORG_GTD="Inbox"`** to avoid inflating the other views' totals. (The unestimated counters already filter by `ORG_GTD=Actions`/`=Someday`, so they're unaffected.)
- **Keys:** `C-c d i` opens the view; sticky dispatch key `"i"` (Someday is `"S"`, Unordered `"u"`).

**Grounding facts:**
- Load path: `init.el` → `(org-babel-load-file "~/.emacs.d/config.org")`. Editing `config.org` then tangling regenerates `config.el` (tracked artifact).
- No `CLAUDE.md` / `verify-plan.sh` in this repo; use `scripts/check-elisp-parens.sh` + a batch-load test for syntax verification.
- Live `.org` data lives on another machine (`thecleverone`/`my-venndoor-life`) — runtime behavior verified by the human at Step 11.

---

## Steps

- [x] **Step 1 — [COMPUTER] Research: confirm config structure & anchor points** _(read-only)_ — `no file changes`

  Confirm the exact line anchors to edit in `config.org`: `org-agenda-files` list, `tdw-someday-priority-view`, `tdw/get-someday-unestimated-count`, `tdw/get-sanity-effort-totals`, `tdw/update-sanity-view-headers`, the `:bind` block, and `org-gtd-capture-templates` usage. No file changes — `no file changes`.

  **✅ Result:** Anchors confirmed:
  - `org-agenda-files` seq-filter list: `config.org` lines 714–719 (hardcoded per-life-area `org-gtd-tasks.org` paths, guarded by `file-exists-p`).
  - `tdw/get-someday-unestimated-count`: lines 1708–1727 — compares `(org-entry-get (point) "ORG_GTD")` to `org-gtd-someday`. Clone target for inbox counter.
  - `tdw/get-sanity-effort-totals` lambda: lines 1033–1045 — filters `(member todo '("NEXT" "TODO"))`, **no `ORG_GTD` filter** → confirms inbox-guard needed (Step 6).
  - `tdw-someday-priority-view`: lines 1758–1863 — buffer `*Org Agenda(S)*`, dispatch key `"S"`, blocks filter `ORG_GTD="Someday"`, calls `tdw/get-someday-unestimated-count`.
  - `tdw/update-sanity-view-headers`: lines 1117–1218 — detection `or` at 1123–1137; per-view title rewrites at 1140–1150 (Ordered 1141–1142, Unordered 1145–1146, Someday is matched as a view by name but its title isn't separately rewritten — uses construction name).
  - `:bind` block: lines 743–757 (`C-c d S`, `C-c d u` present).
  - `org-gtd-capture-templates`: **not set in config.org** → user runs org-gtd defaults (`"i"` Inbox `* %?`, `"l"` link). Step 9 adds an override.

  **📎 Transcript:** Ran greps/seds over `config.org` to read the someday counter, the effort-totals `org-map-entries` lambda, and to confirm `org-gtd-capture-templates` is unset.

  **📝 Learned:** The Someday view's title is set at construction (the `(name . ...)`) and the finalize hook only rewrites Ordered/Unordered titles explicitly — so the banner step must add explicit handling for Someday and Inbox, not assume the hook already covers them.

---

- [x] **Step 2 — [COMPUTER] Add `inbox.org` to `org-agenda-files`**

  In `config.org`, append the org-gtd inbox path to the `org-agenda-files` seq-filter list so the inbox view (and grooming) can see inbox items.

  - [x] Add the inbox path to the list (kept safe by the existing `file-exists-p` filter)
  - [x] Commit — sha `59c9ef9`

  **✅ Result:** Added `"/Users/thecleverone/my-venndoor-life/orgnotes/gtd/inbox.org"` as the first entry of the `org-agenda-files` quoted list (`config.org:715`).

  **📎 Transcript:** **Deviation from plan:** the list is a *quoted* literal (`'(...)`), so `(expand-file-name "inbox.org" stag-org-gtd-directory)` would not be evaluated. Used a literal absolute path matching the existing entries' style instead. Path = `org-gtd-directory` (`~/my-venndoor-life/orgnotes/gtd`) + `inbox.org`, i.e. `org-gtd-inbox-path`. Guarded by the existing `file-exists-p` seq-filter.

  **📝 Learned:** All agenda paths are hardcoded under `/Users/thecleverone`; the inbox sits in the same venndoor gtd dir as the primary tasks file.

---

- [x] **Step 3 — [COMPUTER] Add `tdw/get-inbox-unestimated-count`**

  Clone `tdw/get-someday-unestimated-count`, swapping `ORG_GTD=Someday` → `ORG_GTD=Inbox`. Used for the Inbox view's Unestimated header.

  - [x] Define the new function next to the someday counter
  - [x] Commit — sha `6b8adca`

  **✅ Result:** Added `tdw/get-inbox-unestimated-count` immediately after `tdw/get-someday-unestimated-count` (`config.org` ~1729). Identical body, comparing `ORG_GTD` to the literal `"Inbox"` instead of `org-gtd-someday`. Commit also carries the Step 2 sha correction (`59c9ef9`).

  **📎 Transcript:** Straight clone with the property-value swap; reused `tdw/get-effort-minutes` for the no-effort test.

  **📝 Learned:** Counter compares to the literal `"Inbox"` (no `org-gtd-inbox` constant exists for the *category* — `org-gtd-inbox` in org-gtd is the inbox *filename* base, not an ORG_GTD value).

---

- [x] **Step 4 — [COMPUTER] Add `tdw-inbox-view` function**

  Clone `tdw-someday-priority-view`. Changes: buffer `*Org Agenda(S)*`→`*Org Agenda(i)*`; all block filters `ORG_GTD="Someday"`→`ORG_GTD="Inbox"`; name `Someday View`→`Inbox View`; unestimated count call → `tdw/get-inbox-unestimated-count`; dispatch key `"S"`→`"i"`.

  - [x] Define `tdw-inbox-view`
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `b9970fa` _(source + plan only; `config.el` is gitignored — a build artifact regenerated by `org-babel-load-file`, never committed)_

  **✅ Result:** Added `tdw-inbox-view` directly after `tdw-someday-priority-view`. Byte-for-byte clone of the Someday view with: name `📋 Inbox View`, buffer `*Org Agenda(i)*`, all 11 block filters on `ORG_GTD="Inbox"`, Unestimated header fed by `tdw/get-inbox-unestimated-count`, dispatch key `"i"`. Paren checker passed (tangle + byte-compile clean; only runtime "not known to be defined" warnings, expected in batch).

  **📎 Transcript:** Section effort numbers in the headers (On Fire `(%s)` etc.) and the title `total` come from `tdw/get-sanity-effort-totals`, which counts Actions NEXT/TODO — *identical to how the Someday view already behaves* (those headers reflect the active Actions load, not the section's own items). Kept as-is for parity, per the locked "mirror Someday exactly" decision.

  **📝 Learned:** Adopted the repo's mandatory `scripts/check-elisp-parens.sh` as the per-step verifier (per user request) — it does per-block paren analysis, tangles `config.org`→`config.el`, and byte-compiles in one shot. `config.el` is now committed alongside `config.org` each step to keep the artifact in sync.

---

- [x] **Step 5 — [COMPUTER] Bind `C-c d i` → `tdw-inbox-view`**

  Add the keybinding to the `org-gtd` `use-package` `:bind` block (alongside `C-c d S` / `C-c d u`).

  - [x] Add `("C-c d i" . tdw-inbox-view)`
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `96f83fb`

  **✅ Result:** Added `("C-c d i" . tdw-inbox-view)` to the `org-gtd` `use-package` `:bind` block, right after `C-c d u`. Paren check passed.

  **📎 Transcript:** Single-line addition; commit also carries the Step 4 sha-record correction.

  **📝 Learned:** —

---

- [x] **Step 6 — [COMPUTER] Guard `tdw/get-sanity-effort-totals` against `ORG_GTD="Inbox"`**

  In the `org-map-entries` lambda, skip entries whose `ORG_GTD` is `"Inbox"` so inbox items never inflate the Ordered/Unordered/Someday effort totals.

  - [x] Add the `ORG_GTD="Inbox"` skip guard
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `79adeca`

  **✅ Result:** Wrapped the NEXT/TODO test in `(and … (not (string= (org-entry-get (point) "ORG_GTD") "Inbox")))` in the `tdw/get-sanity-effort-totals` `org-map-entries` lambda, with an explaining comment. Inbox TODO items are now excluded from all effort buckets. Paren check passed.

  **📎 Transcript:** Confirmed the unestimated counters (`tdw/get-actions-unestimated-count`, `tdw/get-someday-unestimated-count`) already filter by `ORG_GTD=Actions`/`=Someday`, so no guard needed there — only this scanner counted by TODO state alone.

  **📝 Learned:** This is the single place where inbox items (which carry a `TODO` keyword for `tags-todo` matching) could have leaked into other views' numbers.

---

- [x] **Step 7 — [COMPUTER] Add `tdw/format-view-banner` helper**

  New helper returning the 2-line **banner A** as a propertized string: a full-width rule line with centered `<icon>  <NAME> VIEW`, plus a second line `Total Estimated Effort: H:MM`. Distinct face for prominence.

  - [x] Define `tdw/format-view-banner` (args: view-name, icon, effort)
  - [x] _(bonus)_ Define `tdw/render-view-banner` (idempotent in-buffer title→banner swap)
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `2afa42e`

  **✅ Result:** Added two helpers before `tdw/update-sanity-view-headers`:
  - `tdw/format-view-banner (label icon effort)` → 2-line propertized string: line 1 = `<12×═>  <icon>  <LABEL> VIEW  <12×═>` (bold, `#5fafff`); line 2 = `Total Estimated Effort: <effort>` (bold).
  - `tdw/render-view-banner (total)` → scans the buffer top for any of the 4 banner-able views (incl. `GTD Engage` → relabeled `Ordered`), deletes the title region (constructed 1-line title **or** an already-rendered 2-line banner — idempotent via case-insensitive `… View` match + consuming a following `Total Estimated Effort:` line), and inserts the fresh banner.

  **📎 Transcript:** Idempotency was the key design point — the finalize hook runs on every agenda refresh, so the swap must recognize its own prior output. Solved by case-folding `Inbox View` ≡ `INBOX VIEW` and optionally consuming the second banner line before re-inserting.

  **📝 Learned:** Fixed 12-char rules each side (not true centering) — robust against emoji `string-width` quirks while still looking like a banner.

---

- [x] **Step 8 — [COMPUTER] Render banner in `tdw/update-sanity-view-headers` for all 4 views**

  Replace the per-view one-line title rewrites (Ordered/Unordered/Someday, and add Inbox) with banner-A rendering via `tdw/format-view-banner`, keyed off each view's detected name. Relabel effort line to `Total Estimated Effort:`. Add `Inbox View` to the view-detection branch at the top of the function. Icons: 📥/💤/📋/🎯.

  - [x] Add `Inbox View` to the detection `or` clause
  - [x] Replace title rewrites with `(tdw/render-view-banner total)` (one call covers all 4 views; Decision rewrite kept as-is)
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `7165235`

  **✅ Result:** Added `(re-search-forward "Inbox View" nil t)` to the detection `or`. Replaced the two `while` title-rewrite loops (Ordered + Unordered) with a single `(tdw/render-view-banner total)` call; the Decision-view total rewrite is preserved below it (Decision is intentionally *not* one of the 4 bannered views). Paren check passed.

  **📎 Transcript:** The Unordered-vs-Ordered substring overlap (`"Unordered View"` contains `"ordered View"`) is handled by ordering `Unordered` before `Ordered` in the renderer's `views` list and `throw 'done` on first match.

  **📝 Learned:** Someday previously had *no* title rewrite in the hook (its title was construction-only); the banner renderer now covers it uniformly, so all four views get consistent treatment from one code path.

---

- [ ] **Step 9 — [COMPUTER] Add `tdw/agenda-move-to-inbox` (re-tag in place)**

  New agenda command mirroring `tdw/agenda-move-to-someday`/`-to-next`, but **option A (re-tag in place — no refile)**: set `ORG_GTD="Inbox"` + `org-todo "TODO"` on the item where it sits, clear stale `CLOSED:`, and update the agenda line's visual marker. Item reappears in the Inbox view immediately (property-based, file-agnostic). If already `ORG_GTD="Inbox"`, just reset the TODO state.

  - [x] Define `tdw/agenda-move-to-inbox`
  - [x] Extend `move-to-someday`/`move-to-next`/`cancel` strip regexes to include `INBOX`
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `e5dda96`

  **✅ Result:** Added `tdw/agenda-move-to-inbox` after `tdw/agenda-cancel`. It sets `ORG_GTD="Inbox"` + `org-todo "TODO"` in place (no refile), clears stale `CLOSED:`, saves, and injects an `INBOX ` visual marker (`font-lock-keyword-face`) — mirroring the someday/next commands' visual logic. Also extended the `SOMEDAY|NEXT|CNCL` strip regexes in `move-to-someday` (819), `move-to-next` (886), and `cancel` (909) to include `INBOX`, so re-grooming a re-inboxed item clears the marker cleanly. Paren check passed.

  **📎 Transcript:** No marker remap needed (unlike the refiling commands) since the item doesn't move — its `org-marker` stays valid.

  **📝 Learned:** Used `TODO` (not `NEXT`) as the keyword for re-inboxed items, matching the LLM item-format contract so they sort into the Inbox view's `tags-todo` blocks identically to captured items.

---

- [ ] **Step 10 — [COMPUTER] Bind `i` to `tdw/agenda-move-to-inbox` in the agenda hook**

  In the `org-agenda-mode-hook` `local-set-key` block, bind `i` → `tdw/agenda-move-to-inbox`, and update the `n/s/x/c` key-semantics comment to include `i=Inbox`.

  - [x] Add `(local-set-key (kbd "i") #'tdw/agenda-move-to-inbox)` + update comment
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `a5c0a28`

  **✅ Result:** Bound `i` → `tdw/agenda-move-to-inbox` in the `org-agenda-mode-hook` `local-set-key` block (between `s` and `n`). Updated the key-semantics comment to `n=Next Action  s=Someday  i=Inbox  x=Cancel  c=Recently Considered (mnemonic: n/s/i/x/c)`. Paren check passed.

  **📎 Transcript:** Lowercase `i` was unbound in the custom hook; capital `I` remains `org-agenda-clock-in`. No conflict with `C-c d i` (prefixed view-opener).

  **📝 Learned:** —

---

- [ ] **Step 11 — [COMPUTER] Stamp `ORG_GTD="Inbox"` in capture templates**

  Override `org-gtd-capture-templates` (the `"i"` Inbox and `"l"` link templates) so manually-captured items get `* TODO …` + `:ORG_GTD: Inbox:` property. Keeps the `C-c d c i` fallback consistent with the LLM contract.

  - [x] Set `org-gtd-capture-templates` with the stamped templates
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `c2d43c9`

  **✅ Result:** Added `org-gtd-capture-templates` to the `org-gtd` `use-package` `:custom` block (before `org-gtd-organize-hooks`). Both `"i"` (Inbox) and `"l"` (Inbox with link) templates now use `* TODO %?` + a `:PROPERTIES:` drawer with `:ORG_GTD: Inbox:`, preserving the original `:before-finalize` CREATED-timestamp hook and `,#'org-gtd-inbox-path` target. Paren check passed.

  **📎 Transcript:** Replicated org-gtd's backquote/`,#'` form so `org-gtd-inbox-path` resolves at load. The `:before-finalize` timestamp hook merges into the existing drawer via `org-entry-put`.

  **📝 Learned:** This is the manual-capture path; the primary populator remains the future LLM workflow emitting the same item shape directly into `inbox.org`.

---

- [ ] **Step 12 — [COMPUTER] Final verification: tangle + paren-check + byte-compile**

  Run the full checker one last time. (`config.el` is gitignored — a build artifact regenerated by `org-babel-load-file` — so nothing to commit here beyond the plan record.)

  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit plan record — sha `09c5611`

  **✅ Result:** Full checker run passed: per-block paren analysis clean, tangle to `config.el` succeeded, byte-compile finished with `ALL CHECKS PASSED`. Pre-existing batch-only noise (missing `org-roam`/`vterm`/`magit`/`git-timemachine` archives under `emacs -q`) is unrelated to this change and present before it. `config.el` not committed (gitignored artifact).

  **📎 Transcript:** Confirmed the four new/edited defuns appear in the byte-compiler's per-function pass with no errors attributed to them.

  **📝 Learned:** The repo's checker doubles as the tangle step — no separate manual tangle needed; `config.el` regenerates here and again at Emacs load via `org-babel-load-file`.

---

- [x] **Step 13 — [HUMAN] Verify in live Emacs** (on `thecleverone`, via an Opus 4.6 agent)

  - [x] `C-c d i` opens the Inbox View — after the buffer-name banner fix (Step 17) and reload
  - [x] Banner renders on all 4 views; user confirmed "Looks great" (then requested full-width centering → Step 18)
  - [x] Someday view now shows all ~332 items (was 25) after the `tags` fix (Step 16)
  - [ ] _(open, optional)_ Phase 4 DONE/CNCL exclusion experiment (counts A/B/C) — not yet run; decides whether to add a `-DONE-CNCL` filter or keep plain `tags`
  - [ ] _(deferred)_ explicit `s`/`n`/`x`/`i` grooming smoke test — covered by design; user can run anytime

  **📎 Transcript:** Verified iteratively across several live round-trips on `thecleverone`: first `C-c d i undefined` (reload needed), then the Someday-items-hidden scare (resolved as the keyword-less/`tags-todo` issue — data was always safe, all in git), then banner-not-rendering (buffer-name fix), then centering. User confirmed the result looks good.

  **📝 Learned:** The cross-machine loop (build on `trace`, test on `thecleverone` via a second agent) worked via the shared `~/.emacs.d` git repo + the handoff prompt in `outputs/handoffs/`.

---

- [x] **Step 14 — [COMPUTER] Capture Context** — see **Resumption / Context** below.

---

- [x] **Step 15 — [COMPUTER] Extract chat transcript** — see **Chat Transcript** below.

---

## Follow-up A — Someday/Inbox keyword-less visibility

**Trigger:** On `thecleverone`, the user found 307 / 332 Someday items were *invisible* in the Someday view. Root cause (pre-existing, not introduced by this work): the view blocks use `tags-todo`, which only matches headings that carry a TODO keyword. org-gtd's someday flow (`org-todo ""`, mirrored by `tdw/agenda-move-to-someday`) clears the keyword, so 92% of Someday items had no keyword and were filtered out. Data was never lost (all 332 on disk; org files in git).

- [x] **Step 16 — [COMPUTER] Switch Someday + Inbox view blocks from `tags-todo` to `tags`**

  Plain `tags` (todo-only nil) matches headings regardless of keyword, surfacing the keyword-less items. Scoped strictly to the two view functions; the Actions-based views (Unordered/Ordered/Decision) keep `tags-todo` (their items always carry NEXT/TODO).

  - [x] `sed` scoped to lines 1881–1986 (Someday) and 1989–2095 (Inbox): `(tags-todo` → `(tags` (22 occurrences, 11+11)
  - [x] Verified 46 `tags-todo` remain (Actions views untouched); diff is `tags-todo`→`tags` only
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `6ef37ef`

  **✅ Result:** 22 block types changed across the Someday and Inbox views. All `ORG_GTD="Someday"`/`"Inbox"` items now display regardless of TODO keyword.

  **📎 Transcript:** Went with **plain `tags`** (no `/` TODO filter) for guaranteed correctness — it definitely surfaces keyword-less items. Trade-off: DONE/CNCL Someday items now also appear. Deferred the DONE/CNCL exclusion (`/-DONE-CNCL` or `TODO<>"DONE"`) to a live-verified follow-up, since its exact semantics for keyword-less items must be confirmed on real data before committing.

  **📝 Learned:** This resolves the long-standing "how do keyword-less someday items show in a `tags-todo` block?" puzzle from Step 1 — they *didn't*; the view had been silently hiding them.

---

- [x] **Step 17 — [COMPUTER] Fix banner detection: key off buffer name, insert at point-min**

  **Trigger:** Live test on `thecleverone` — banner not rendering. `tdw/render-view-banner` searched the buffer for the view `name` text ("Someday View" / "Inbox View"), but org renders the view `name` only as the agenda-*dispatcher* description; it is **not in the buffer body**. (Likely why the user wanted a visible banner in the first place — and why the old Ordered/Unordered title rewrites were probably no-ops.)

  - [x] Rewrite `tdw/render-view-banner` to identify the view by sticky buffer name `*Org Agenda(KEY)*` (i=Inbox, S=Someday, u=Unordered, g=Ordered) and insert the banner at `point-min`; idempotent (strips a prior banner via the `═` rule-line marker)
  - [x] Confirmed `org-agenda-sticky t` (config.org:3015) and `org-gtd-engage` → key `"g"`
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `2b335b8`

  **✅ Result:** Buffer-name detection replaces fragile title-text search. The finalize hook (`tdw/update-sanity-view-headers`) still fires for these views via the section-header matches in its `when (or …)` gate (e.g. "🔥🔥 On Fire"), so `tdw/render-view-banner` is reached; it now self-gates on buffer key and renders at the top. Survives `g`/redo because the buffer name is stable.

  **📎 Transcript:** Engage (Ordered) uses `org-gtd-view-show` with no key → default `"g"` → `*Org Agenda(g)*`. Inbox/Someday/Unordered keys (i/S/u) match the buffers the view functions already kill-and-recreate.

  **📝 Learned:** For sticky agendas, the buffer name `*Org Agenda(KEY)*` is the most reliable per-view discriminator — the `(name . …)` DSL field never reaches the buffer text.

---

- [x] **Step 18 — [COMPUTER] Full-width, centered banner**

  **Trigger:** User asked for the banner rows to span the full screen width with the title centered (was fixed 12-char rules).

  - [x] Rewrite `tdw/format-view-banner` to compute width from the agenda window (`window-width`, fallback 80, minus 1 to avoid wrap), center the title between `═` rules filling the width, and center the `Total Estimated Effort:` line
  - [x] Update the idempotency strip in `tdw/render-view-banner` to `(looking-at ".*═")` (rule line may no longer start with `═` when left-pad is small)
  - [x] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [x] Commit — sha `5ada6ac`

  **✅ Result:** Banner rule line now spans the full window width with `<icon>  <LABEL> VIEW` centered; effort line centered beneath. Uses `string-width` so emoji (2 cols) align. Width recomputed each render (re-centers on the next refresh after a resize).

  **📎 Transcript:** Subtract 1 from `window-width` to avoid edge wrap; `max 1` guards on both pads so a very narrow window or long title can't produce negative fills.

  **📝 Learned:** —

---

## Resumption / Context

**Status at capture (final):** All steps complete and pushed, including the live-verification round-trips and three follow-up fixes (Steps 16–18). HEAD = `5ada6ac`. The user confirmed the result looks good. Only optional open item: the Phase 4 DONE/CNCL count experiment (decides whether to hide DONE/CNCL Someday items via a match filter vs. the current plain `tags`).

**Repo:** `~/.emacs.d` — branch `master`, pushed to `github.com:tracedwax/.emacs.d`. Final HEAD `5ada6ac`.

**Follow-up commits (after the original 13):**
- `e864fbd` — docs(plan): capture context + chat transcript (Steps 14–15)
- `6ef37ef` — fix(views): show keyword-less Someday/Inbox items (`tags` vs `tags-todo`) — **Step 16**
- `f489f2c` — docs(handoff): `thecleverone` verification prompt (`outputs/handoffs/2026-06-10_thecleverone-verify-inbox-view.md`)
- `2b335b8` — fix(banner): detect view by sticky buffer name, render at point-min — **Step 17** (the real banner fix)
- `5ada6ac` — feat(banner): full-width centered banner — **Step 18**

**Three live-surfaced fixes (important for future readers):**
1. **Someday items "disappeared" (307/332 hidden):** pre-existing — `tags-todo` needs a TODO keyword, org-gtd clears it on Someday. Fixed by switching Someday + Inbox view blocks to plain `tags` (Step 16). No data was lost; org files are in git.
2. **Banner not rendering:** the view `name` is only the agenda *dispatcher description*, never in the buffer body — so the original title-text search never matched. Fixed by keying off the sticky buffer name `*Org Agenda(KEY)*` (i/S/u/g) and inserting at point-min (Step 17).
3. **Banner width:** centered full-window-width via `window-width` + `string-width` (Step 18).
**Source of truth:** `config.org`. `config.el` is a **gitignored** build artifact regenerated by `(org-babel-load-file "~/.emacs.d/config.org")` in `init.el`.

**Commits (in order):**
1. `74bfd06` — docs(plan): inbox-view HITL plan + Step 1 research findings
2. `59c9ef9` — feat(agenda): add inbox.org to org-agenda-files
3. `6b8adca` — feat(inbox): add tdw/get-inbox-unestimated-count (+ Step 2 sha fix)
4. `b9970fa` — feat(inbox): add tdw-inbox-view mirroring the Someday view
5. `96f83fb` — feat(inbox): bind C-c d i to tdw-inbox-view
6. `79adeca` — fix(agenda): exclude ORG_GTD=Inbox from sanity effort totals
7. `135c146` — docs(plan): add re-inbox 'i' grooming key (Steps 9-10), renumber tail
8. `2afa42e` — feat(agenda): add view-banner helpers (format + idempotent render)
9. `7165235` — feat(agenda): render banner-A on Inbox/Someday/Unordered/Ordered views
10. `e5dda96` — feat(agenda): add tdw/agenda-move-to-inbox (re-tag in place)
11. `a5c0a28` — feat(agenda): bind i to tdw/agenda-move-to-inbox
12. `c2d43c9` — feat(capture): stamp ORG_GTD=Inbox + TODO in org-gtd capture templates
13. `09c5611` — docs(plan): Step 12 final verification — ALL CHECKS PASSED

**What changed in `config.org` (anchors approximate; verify by name):**
- `org-agenda-files` list: added `".../my-venndoor-life/orgnotes/gtd/inbox.org"` as first entry.
- New `tdw/get-inbox-unestimated-count` (after `tdw/get-someday-unestimated-count`).
- New `tdw-inbox-view` (after `tdw-someday-priority-view`): clone of Someday filtered on `ORG_GTD="Inbox"`, buffer `*Org Agenda(i)*`, dispatch key `"i"`.
- `:bind` block: `("C-c d i" . tdw-inbox-view)`.
- `tdw/get-sanity-effort-totals`: lambda now skips `ORG_GTD="Inbox"` items.
- New `tdw/format-view-banner` + `tdw/render-view-banner` (before `tdw/update-sanity-view-headers`).
- `tdw/update-sanity-view-headers`: added `Inbox View` to detection `or`; replaced Ordered+Unordered title rewrites with `(tdw/render-view-banner total)`; Decision rewrite kept.
- New `tdw/agenda-move-to-inbox` (after `tdw/agenda-cancel`): re-tags `ORG_GTD="Inbox"` + `TODO` in place, no refile. `INBOX` added to the SOMEDAY/NEXT/CNCL strip regexes in someday/next/cancel commands.
- `org-agenda-mode-hook`: bound `i` → `tdw/agenda-move-to-inbox`; updated key-semantics comment.
- `org-gtd-capture-templates` added to `:custom`: `"i"` and `"l"` templates stamp `* TODO %?` + `:ORG_GTD: Inbox:`.

**Verification command (run after every elisp edit):** `~/.emacs.d/scripts/check-elisp-parens.sh` → expect `=== ALL CHECKS PASSED ===`. (Pre-existing batch-only errors for `org-roam`/`vterm`/`magit`/`git-timemachine` are unrelated.)

**Key decisions (locked via grill-me):**
- Inbox membership = `ORG_GTD="Inbox"` property (peer to Someday/Actions), not a separate clarify flow.
- Items carry a `TODO` keyword so `tags-todo` blocks match them; the view hides the keyword (`org-agenda-todo-keyword-format ""`).
- Reuse org-gtd's existing `inbox.org` as the holding pen; add to `org-agenda-files`.
- Inbox view clones the **Someday** section set (not Unordered).
- Banner style **A** (ruled line + `Total Estimated Effort:`) on all 4 views; icons 📥/💤/📋/🎯.
- Re-inbox key `i` = **option A** (re-tag in place, no refile).
- Primary population = a future LLM workflow command emitting the item-format contract; `C-c d c i` is a rare manual fallback.

**Deviations from plan:** Step 2 used a literal path string (the `org-agenda-files` list is a *quoted* literal, so `expand-file-name` wouldn't evaluate). Step 10 originally specced committing `config.el`; dropped because it's gitignored.

**If resuming after the human test finds issues:** add new numbered steps after Step 15, re-run the checker per edit, microcommit each, and append to this context block.

---

## Chat Transcript

**User:** please pull rebase .emacs.d
*(then, switching model + design intent)* I want to create an inbox view that works identically to the someday view and the unordered view, same display, tags, everything. Just it's kept in an inbox. my config.org is in ~/.emacs.d and org-gtd is in workspace/oss/Trevoke. /grill-me for what I want and how this can work similar and different to org-gtd. Functionally it is a gtd inbox. But I won't be clarifying the way that Trevoke hardcodes; my flow will be that I will groom each task to someday (s) next action for the unordered view (n) or canceled (x). For next actions I may groom them further but not yet.

**Claude:** Pulled & rebased `.emacs.d` (stashed an uncommitted plan edit, rebased onto `origin/master`, restored). Explored config: both views are `org-gtd-view-show` calls filtering `tags-todo` on `ORG_GTD`; the `s`/`n`/`x` move commands already work from any state; org-gtd's native inbox captures bare headings with no TODO keyword (invisible to a mirror view). Began grilling.

**User:** (asked to clarify before answering the inbox-marker question)

**Claude:** Explained the crux: the view filters by the `ORG_GTD` *property* across all agenda files, so "how an item is marked" and "which file it lives in" are independent. Recommended `ORG_GTD="Inbox"` marker + reuse Trevoke's inbox.org.

**User:** option 1 [ORG_GTD="Inbox"], I think. It is a peer to 'someday'. There's still an inbox but I'm not sure how the inbox file works. Advise and ask me, knowing my flow.

**Claude:** Confirmed marker = `ORG_GTD="Inbox"`; file is an independent choice; grooming always lands items in org-gtd-tasks.org so a dedicated inbox file empties as you groom. Asked: file location, layout to mirror, tags-at-capture.

**User:** what I want is a display that looks identical to the other views. Also label the top as Inbox/Unordered/Ordered/Someday View so I don't get confused — at the tippy top.

**Claude:** Clarified "identical" = identical styling (the views differ in section sets). Recommended cloning the Someday section set. Asked banner style (A title-only vs B prominent banner on all 4).

**User:** Yes, the someday view's sections. B — prominent banner for all 4 views.

**Claude:** Locked Someday sections + banner on all 4. Proposed banner styles A/B/C and per-view icons; asked file + keys.

**User:** A, but put Total Estimated Effort in the header.

**Claude:** Locked banner A with `Total Estimated Effort:`. Confirmed remaining: scope (all 4), file (new inbox.org), keys (`C-c d i`, dispatch `"i"`).

**User:** All sounds good but shouldn't my existing inbox.org be empty so you can just use it?

**Claude:** Agreed — reuse Trevoke's existing inbox.org (simpler, capture path unchanged); bare pre-existing items just won't show (no `ORG_GTD`).

**User:** yes and capture this transcript and capture a commit at every step you execute

**Claude:** Invoked `/create-hitl-plan`, wrote the plan, began executing COMPUTER steps with a microcommit each.

**User:** Are you able to count parens to make sure you get them right? there should be some sort of count parens function you can use.

**Claude:** Found `scripts/check-elisp-parens.sh` (per-block paren analysis + tangle + byte-compile) and wired it into every elisp step.

**User:** CAn I move things back to the inbox by hitting 'i' when I groom them from someday or elsewhere?

**Claude:** Not yet, but easy to add — `tdw/agenda-move-to-inbox` bound to `i`. Asked the fork: re-tag in place (A) vs physically move to inbox.org (B).

**User:** A please.

**Claude:** Added Steps 9–10 to the plan; implemented the re-tag-in-place command + `i` binding.

**User:** Push this up to origin and I'll test with my latest account.

**Claude:** Pushed `master` to origin (`10a630c..09c5611`); completed capture-context + transcript. Step 13 (live verification) awaits the user's test.

**User:** says C-c d i is undefined

**Claude:** Confirmed the binding is correct in tangled `config.el` (line 567) and the defun exists — so the running Emacs just needs to reload. Gave `M-x org-babel-load-file RET ~/.emacs.d/config.org RET` + `(fboundp 'tdw-inbox-view)` check.

**User:** Also most of my someday tasks disappeared except the newest, which is terrifying.

**Claude:** Reassured: nothing I wrote deletes org-file content; the agenda is a query, data lives in the files. Most likely items got re-tagged (or it's a display issue). Gave steps to find them (open the file, search `:ORG_GTD: Inbox`, check git diff). Asked: did you reload? press bare `i`? are org files in git?

**User:** I did not press i bare. Everything is in git. There it is — 307 Someday items invisible (no TODO keyword), 25 visible; 92% hidden because `tags-todo` only matches headings with a keyword.

**Claude:** Confirmed data safe (332 all on disk, in git). Diagnosed the pre-existing `tags-todo`-needs-a-keyword limitation (org-gtd clears the keyword on Someday). Confirmed retangle must happen on `thecleverone`, not `trace`. Proposed the view-only `tags` fix (zero data risk). Asked to proceed.

**User:** A please. *(earlier — re the re-inbox key)* … then: I did not press i bare; everything is in git; another Opus 4.6 is running it on the data machine — give me a wildly detailed prompt to test.

**Claude:** Implemented the `tags` fix (Step 16, scoped to Someday + Inbox views, Actions views keep `tags-todo`), committed + pushed. Wrote a detailed handoff prompt for the `thecleverone` agent (saved to `outputs/handoffs/`) covering: git safety check, pull+reload, definition/binding checks, Someday-count snippet, and a DONE/CNCL match-syntax experiment.

**User:** WE are close. Banner not rendering — `tdw/render-view-banner` defined but not called by the finalize hook; view-name detection may not be matching. Needs investigation on `trace`.

**Claude:** Investigated: the updater IS hooked and fires; the real bug is that the view `name` is only the dispatcher description, never in the buffer body, so the title-text search failed. Rewrote `tdw/render-view-banner` to key off the sticky buffer name `*Org Agenda(KEY)*` (i/S/u/g) and insert at point-min (Step 17). Committed + pushed.

**User:** Looks great but are you able to center the header rows so they cover the full screen width?

**Claude:** Rewrote `tdw/format-view-banner` to span the full window width with a centered title between `═` rules, and centered the effort line (Step 18). Committed + pushed.

**User:** complete the plan and capture the full transcript. we should be done.

**Claude:** Marked Step 13 verified (banner renders, Someday items visible, user approved), updated the context block with the follow-up commits and the three live-surfaced fixes, appended this transcript, and did the final commit (`6e37d92`). Summarized what shipped + the one optional loose end (Phase 4 DONE/CNCL count experiment).

**User:** capture this last into the plan and I'll close the window.

**Claude:** Appended this closing exchange to the transcript and committed (final). Session complete.

---

## Open / Future (carried forward)

- **Phase 4 — DONE/CNCL exclusion (optional):** Someday view now uses plain `tags`, so DONE/CNCL Someday items also appear. To hide them without re-hiding keyword-less items, run the A/B/C count experiment in `outputs/handoffs/2026-06-10_thecleverone-verify-inbox-view.md` on real data, then adopt `/-DONE-CNCL` or `TODO<>"DONE"` in the Someday/Inbox match strings if it preserves the keyword-less items.
- **Optional "give every Someday item a real keyword" migration:** the deeper cleanup (so `tags-todo` would work everywhere). Do with a git checkpoint + dry-run if ever desired.
- **LLM workflow command:** the future populator that emits the item-format contract directly into `inbox.org` (the primary intended capture path).
