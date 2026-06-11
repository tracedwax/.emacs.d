# HITL Plan: OpenSpec Update and Init in .emacs.d

**Created:** 2026-06-05

---

## Steps

- [x] **Step 1 — [COMPUTER] Verify openspec installation**

  Check whether `openspec` is installed, which binary is on PATH, and what version is active.

  - [x] Run `which openspec && openspec --version`
  - [x] Confirm package is `@fission-ai/openspec` (bare `openspec` on npm is an unrelated stub at v0.0.0)

  **✅ Result:** Binary found at `/Users/trace/.local/share/mise/installs/node/lts/bin/openspec`, version `1.3.1`. Installed as `@fission-ai/openspec` global via mise-managed Node LTS.

---

- [x] **Step 2 — [COMPUTER] Check latest upstream version**

  Run `npm view @fission-ai/openspec version` to confirm what the latest release is.

  **✅ Result:** Latest version on npm registry is `1.4.1`.

---

- [x] **Step 3 — [COMPUTER] Update openspec to latest**

  Run `npm install -g @fission-ai/openspec@latest` under the mise Node LTS toolchain.

  - [x] Verify `openspec --version` reports `1.4.1` after update
  - [x] Confirm mise reshimmed automatically (seen in npm output: "Reshimming mise lts...")

  **✅ Result:** Updated from `1.3.1` → `1.4.1`. mise reshimmed automatically. `openspec --version` → `1.4.1`.

---

- [x] **Step 4 — [COMPUTER] First `openspec init` run (accidental Gemini default)**

  Ran `openspec init` with no flags. In non-interactive mode it defaulted to the Gemini CLI integration.

  - [x] Created `openspec/changes/archive/` and `openspec/specs/` directory structure
  - [x] Created `.gemini/commands/` (5 commands)
  - [x] Created `.gemini/skills/` (7 skills)

  **✅ Result:** Structure created but wrong tool target. Pre-existing `.gemini/settings.json` (dated 2026-03-13) was left unchanged.

---

- [x] **Step 5 — [COMPUTER] Re-run `openspec init --tools claude`**

  Re-initialize explicitly targeting Claude Code integration.

  - [x] Run `openspec init --tools claude`
  - [x] Confirm `.claude/commands/opsx/` contains 5 commands: `apply.md`, `archive.md`, `explore.md`, `propose.md`, `sync.md`
  - [x] Confirm `.claude/skills/` contains 5 skills: `openspec-apply-change`, `openspec-archive-change`, `openspec-explore`, `openspec-propose`, `openspec-sync-specs`
  - [x] Confirm `openspec/` structure intact

  **✅ Result:** Claude Code integration fully installed. `openspec init` output: "5 skills and 5 commands in .claude/". Note: tool reports it migrated a "custom profile with 5 workflows" from a global mise config.

---

- [x] **Step 6 — [HUMAN] Approve removal of stray Gemini dirs**

  The first (accidental) init run created `.gemini/commands/` and `.gemini/skills/`. User confirmed these should be removed.

  **✅ Result:** User selected "Yes, remove them" when prompted.

---

- [x] **Step 7 — [COMPUTER] Remove stray Gemini OpenSpec files**

  Delete `.gemini/commands/` and `.gemini/skills/` only. Leave `.gemini/settings.json` (pre-existing, dated 2026-03-13).

  - [x] Run `rm -rf .gemini/commands .gemini/skills`
  - [x] Confirm only `.gemini/settings.json` remains

  **✅ Result:** Stray dirs removed. `.gemini/` now contains only the pre-existing `settings.json`.

---

- [x] **Step 8 — [COMPUTER] Commit changes**

  Stage and commit the new files created by openspec init.

  - [x] `git add .claude/ openspec/ outputs/`
  - [x] Commit with message documenting the openspec init
  - [x] Commit — sha `badf523`

  **✅ Result:** Committed 11 files (10 openspec-generated, 1 HITL plan). sha `badf523`.

---

- [x] **Step 9 — [COMPUTER] Capture Context**

  Append complete resumption block to this plan file.

  **Commands run (in order):**
  ```
  which openspec; openspec --version
  npm view openspec version
  openspec --version
  npm ls -g openspec
  npm view openspec
  npm view @fission-ai/openspec version
  npm ls -g @fission-ai/openspec
  npm install -g @fission-ai/openspec@latest
  hash -r; openspec --version
  openspec init
  git status --short
  ls -la openspec/ .gemini/
  openspec init --help
  openspec init --tools claude
  git status --short
  rm -rf .gemini/commands .gemini/skills
  ls -la .gemini/
  git status --short
  ```

  **Working directory:** `/Users/trace/.emacs.d`

  **Final file state:**
  ```
  .claude/commands/opsx/apply.md
  .claude/commands/opsx/archive.md
  .claude/commands/opsx/explore.md
  .claude/commands/opsx/propose.md
  .claude/commands/opsx/sync.md
  .claude/skills/openspec-apply-change/SKILL.md
  .claude/skills/openspec-archive-change/SKILL.md
  .claude/skills/openspec-explore/SKILL.md
  .claude/skills/openspec-propose/SKILL.md
  .claude/skills/openspec-sync-specs/SKILL.md
  openspec/changes/archive/   (empty dir)
  openspec/specs/             (empty dir)
  .gemini/settings.json       (pre-existing, untouched)
  ```

  **Global tool state:**
  - `@fission-ai/openspec@1.4.1` installed globally under mise Node LTS at `/Users/trace/.local/share/mise/installs/node/lts/`

  **✅ Result:** Captured above.

---

- [x] **Step 10 — [COMPUTER] Extract chat transcript**

  Append human-readable conversation below.

  **✅ Result:** Transcript embedded below.

---

## Chat Transcript

**User:** How is my openspec install? Do I have it?

**Claude:** Checked — yes, you have it.
- Binary: `/Users/trace/.local/share/mise/installs/node/lts/bin/openspec`
- Version: `1.3.1`
- Installed via mise-managed Node LTS as `@fission-ai/openspec`

**User:** I know it does not. My version of openspec is behind. Can you update it?

**Claude:** Checked latest: `@fission-ai/openspec@1.4.1`. You're on `1.3.1`. Ran `npm install -g @fission-ai/openspec@latest`. Updated to `1.4.1`, mise reshimmed automatically.

**User:** Please run openspec init in this repo

**Claude:** Ran `openspec init` — defaulted to Gemini CLI in non-interactive mode. Re-ran `openspec init --tools claude` to target Claude Code. Installed 5 skills and 5 commands in `.claude/`. Noted stray `.gemini/commands/` and `.gemini/skills/` from the first run, asked user whether to remove them. User said yes — removed. Final state: Claude Code integration live, `.gemini/` only has pre-existing `settings.json`.

**User:** (switched model to Sonnet 4.6, then invoked /create-hitl-plan to capture everything we just did in the repo, the transcript, the context and whatnot.)

**Claude:** Generated this HITL plan at `outputs/hitl-plans/2026-06-05_openspec-init-and-update.md`.

**User:** yes, and I don't need to make final reviews. Please don't ask me. Change my CLAUDE.md in ~ to say never to wait for my permission to review or finish out the end of a HITL plan or begin a computer step. I'm only needed for the HUMAN steps. Change the default create-hitl-plan skill in ~ for this also.

**Claude:** Created `~/.claude/CLAUDE.md` with autonomous COMPUTER step execution rule. Updated `~/.claude/skills/create-hitl-plan/SKILL.md` to add "Autonomous Execution" section with the same constraint. Completed plan steps 8–10 without asking. Committed sha `badf523`.
