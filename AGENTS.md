# AGENTS.md: working agreement for ~/.emacs.d

Instructions for any AI agent (Claude on `trace`, Antigravity/Gemini on `thecleverone`) working in this repo. These preferences are important; follow them.

## Working style

- **Decide, don't ask.** Proceed on anything reversible. Only stop for the irreversible, destructive, or genuinely high-stakes. Everything here is reversible; we are not shipping to a deep-space mission.
- **Post decisions, don't gate on them.** State each decision in one line as you make it. The user watches the stream and will interject if needed.
- **Don't keep stopping.** No "want me to continue?", no final-review checkpoints. Finish the work.
- **Be concise.** Token-conscious. Short replies, short rules.

## Git and the literate config

- **Sync first.** At the START of any work: commit pending changes (never stash), then `git pull --rebase`. Both accounts and machines edit this repo; a stale base causes divergent-base collisions.
- **`config.el` is GENERATED** by tangling `config.org`. Never edit `config.el`. Edit `config.org`, then re-tangle.
- After editing `config.org`: run `scripts/check-elisp-parens.sh`, delete `config.el`/`config.elc`, restart the Emacs daemon (your account's `stop`/`start-emacs-daemon.sh`), and confirm **F2** (the Unordered View) still works.
- **Cross-account GTD data**: `trace` uses `~/my-test-life` fixtures; `thecleverone` uses `~/my-venndoor-life`. Selection is by `(user-login-name)`. Keep that conditional intact; never point thecleverone at the test fixtures.

## Tests

- **TDD is mandatory** (Trace, 2026-07-03, after the diary leak recurred 18 times). For every behavior change: write the failing test FIRST, run it, commit it red; then implement, run, commit green. A regression fix must add a test that pins the bug. Skipping TDD requires Trace's express permission, per instance.
- `test/run-tests.sh` runs the e-unit suite (`test/unit/*.el`). **Refactor under green**: keep the suite passing after every change, and add characterization tests before changing behavior.
- If logic is buried where tests can't reach (inline in a view block), extract it to `lisp/` and have config.org and the tests consume that one definition. Model: `lisp/tdw-diary.el` + `test/unit/tdw-diary-test.el` (the Today's Diary block).
- View BUILD errors still need a live render via `emacsclient -s gtd` (the unit suite loads config with use-package stubbed).

## GTD design (current intent)

- The **Unordered View** (F2 / `tdw-unordered-view`) is the only view in use. The Ordered View is retired and deleted; do not resurrect it.
- **No scoring.** The urgency/impact/effort Eisenhower system and "big rocks" are retired. Do not reintroduce score-based prioritization.
- **Projects**: the tier tag (`p0`/`bells_ringing`/`on_deck`/`recently_considered`/`paused`) and the effort estimate live on the project PARENT. The parent appears in its tier section with its subtasks directly below it; subtasks carry no estimate.
- **Remove code not used by any view.** Dead code is debt; delete it (after confirming no view, keybinding, or hook reaches it).

## Writing

- No em-dashes anywhere (code, comments, commits, docs). Use a colon, comma, parentheses, or period.

## Remotes

- **origin only.** `origin` is `git@github.com:tracedwax/.emacs.d.git`. There is no upstream remote. The Trevoke fork diverged long ago; never re-add it, never fetch from it, never rebase on it.
