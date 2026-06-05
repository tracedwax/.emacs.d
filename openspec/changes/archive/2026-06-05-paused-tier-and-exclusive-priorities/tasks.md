## 1. Source of truth & shared command

- [x] 1.1 Add `tdw--tier-tags` defvar — ordered list `(on_fire bells_ringing on_deck recently_considered paused)` — near the existing tier helpers; this is the single source of truth for "which tags are tiers"
- [x] 1.2 Factor the in-place prefix-update logic out of the four `tdw/agenda-toggle-*` commands into one shared helper (`tdw/agenda--refresh-prefix`), preserving both render styles: Ordered View (`… U:xx I:xx [nn]`) and Unordered View (`🔥 U:xx I:xx`)
- [x] 1.3 Implement `tdw/agenda-set-tier (TAG)`: on the entry at point, remove every tag in `tdw--tier-tags`; if the entry already had `TAG`, leave it cleared (radio "off"); otherwise add `TAG`; then refresh the prefix — mirrors the remove-old/add-new pattern of `tdw/agenda-cycle-tag`. (No score recompute: tiers are orthogonal to score, matching the old toggles.)
- [x] 1.4 Remove the four now-obsolete commands `tdw/agenda-toggle-on-fire` / `-bells-ringing` / `-on-deck` / `-recently-considered` (kept `-google` and `-flyby`)

## 2. Key bindings

- [x] 2.1 Repoint `f`/`b`/`d`/`c` to `tdw/agenda-set-tier` with `"on_fire"`/`"bells_ringing"`/`"on_deck"`/`"recently_considered"`
- [x] 2.2 Bind `p` → `(tdw/agenda-set-tier "paused")`
- [x] 2.3 Confirmed no other binding changed — `g` google, `l` flyby, `r` sanity-refresh, `u`/`i` cycle all intact (verified in tangled `config.el`)

## 3. Paused display

- [x] 3.1 Add `paused → "🕐 "` to `org-gtd-agenda--resolve-score` and `--resolve-urg-imp` (single-glyph prefix, like siblings)
- [x] 3.2 Add `🕐 Paused` `tags-todo` block as the **last** tier block (after Recently Considered) in the Someday Priority View, copying the sibling block's sorting/prefix-format
- [x] 3.3 Add the same `🕐 Paused` block, last among tier blocks, in the Unordered View
- [x] 3.4 No tier block for the Ordered View (`org-gtd-engage`): it renders tiers as inline prefix glyphs sorted by score, so it is fully covered by the `🕐` prefix from 3.1 — no block to add. (Inline rendering confirmation folded into live check 5.2.)
- [x] 3.5 Add `"paused"` to `tdw--excluded-tag-prefixes`

## 4. Paused header effort total

- [x] 4.1 Add `🕐 Paused` to the header-detection `or` in `tdw/update-sanity-view-headers`
- [x] 4.2 Add a Paused branch to the per-tier effort updater that writes the total into `🕐 Paused (…)`, matching `🔥🔥 On Fire (…)`
- [x] 4.3 Compute the total in `tdw/get-sanity-effort-totals`: added `mins-paused` accumulator + a `(tdw/paused-p)` cond clause (before big-rock, so paused tasks count as paused), appended to the returned list, and threaded `,effort-paused` through all three `pcase-let` destructures (finalize, Someday, Unordered). TOTAL deliberately **excludes** paused (parked work doesn't inflate active load). NOTE: original task text pointed at the warnings push (~1030) — that is capacity warnings (Recently Considered has none, so Paused needs none); the real effort source is `get-sanity-effort-totals`.

## 5. Tangle, verify, validate

- [x] 5.1 Re-tangled `config.org` → `config.el` (via the same matcher `org-babel-load-file` uses: both `emacs-lisp` **and** `elisp` blocks — an initial `emacs-lisp`-only tangle silently dropped the `elisp` blocks). Validated: `check-parens` OK, 295 forms read OK, diff vs. backup shows only intended changes.
- [x] 5.2 **(needs live Emacs)** Load in the real running Emacs (daemon / SSH terminal) and confirm `🕐` renders with **no redraw corruption**, including inline in the Ordered View
- [x] 5.3 **(needs live Emacs)** Verify radio behavior: `f`/`b`/`d`/`c`/`p` set exactly one tier; re-pressing the active tier clears to no tier; tiers never stack
- [x] 5.4 **(needs live Emacs)** Verify the Paused block renders last among tier blocks in both Someday and Unordered views, and the per-task prefix updates in place (both styles) after a tier change
- [x] 5.5 **(needs live Emacs)** Verify the `🕐 Paused` header shows a correct effort total that updates as tasks are paused/unpaused
- [x] 5.6 `openspec validate paused-tier-and-exclusive-priorities --strict` → valid
