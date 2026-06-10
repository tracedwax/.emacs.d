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
  - [x] Commit — sha `step11tbd`

  **✅ Result:** Added `org-gtd-capture-templates` to the `org-gtd` `use-package` `:custom` block (before `org-gtd-organize-hooks`). Both `"i"` (Inbox) and `"l"` (Inbox with link) templates now use `* TODO %?` + a `:PROPERTIES:` drawer with `:ORG_GTD: Inbox:`, preserving the original `:before-finalize` CREATED-timestamp hook and `,#'org-gtd-inbox-path` target. Paren check passed.

  **📎 Transcript:** Replicated org-gtd's backquote/`,#'` form so `org-gtd-inbox-path` resolves at load. The `:before-finalize` timestamp hook merges into the existing drawer via `org-entry-put`.

  **📝 Learned:** This is the manual-capture path; the primary populator remains the future LLM workflow emitting the same item shape directly into `inbox.org`.

---

- [ ] **Step 12 — [COMPUTER] Final verification: tangle + paren-check + byte-compile**

  Run the full checker one last time. (`config.el` is gitignored — a build artifact regenerated by `org-babel-load-file` — so nothing to commit here beyond the plan record.)

  - [ ] `scripts/check-elisp-parens.sh` → `ALL CHECKS PASSED`
  - [ ] Commit plan record — sha `___`

---

- [ ] **Step 13 — [HUMAN] Verify in live Emacs**

  In a running Emacs:
  - [ ] `C-c d i` opens the Inbox View with banner A (`📥 INBOX VIEW`, `Total Estimated Effort:`)
  - [ ] Banner A renders on Someday (💤), Unordered (📋), Ordered (🎯) too
  - [ ] Capture a test item via `C-c d c i` → appears in Inbox View
  - [ ] `s` / `n` / `x` groom it out; item leaves the inbox and lands in Someday/Actions/Cancelled
  - [ ] From Someday/Unordered, press `i` on an item → it re-tags to Inbox and shows in the Inbox view
  - [ ] Unordered/Someday/Ordered effort totals unchanged by the presence of inbox items

---

- [ ] **Step 14 — [COMPUTER] Capture Context**

  Append a complete resumption block: every commit SHA, every decision, exact commands, any deviations.

---

- [ ] **Step 15 — [COMPUTER] Extract chat transcript**

  Append the full human-readable grill-me conversation that produced this design.
