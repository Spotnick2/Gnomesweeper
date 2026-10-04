# AGENTS.md

Shared entry point for non-Claude agents (Codex, Copilot). **`CLAUDE.md` is the source of truth**
for this repo: what Gnomesweeper is, the layout, the decided game rules, the Forever client facts,
the toolchain, testing and workflow. Read it first; nothing here overrides it.

**Reviews:** use `$wow-addon-review` for routing, scope, evidence and the finding format; post every
PR review on the PR. Backlog and PRs: `github.com/Spotnick2/Gnomesweeper`.

Quick facts, in case you read only this:

- WoW: Forever addon, Interface `16001`, **Lua 5.1**, Retail API on Vanilla content.
- Validate: `pwsh tests\run.ps1` (luac -p on every TOC file + all `tests\test_*.lua`).
- `Board.lua` is pure Lua with no WoW API — keep it that way.
- The glass material is the embedded LibGlass-1.0 (`Libs\LibGlass-1.0\`, from `.pkgmeta`
  externals, gitignored); material changes are LibGlass PRs. The tests need a LibGlass checkout
  (`..\LibGlass` or `$LIBGLASS`). Our own art is `Skin.MEDIA`, never `Glass.MEDIA`.
- Never commit a literal version over `## Version: @project-version@`.
- Review context: `C:\Projects\References\PORTING-TBC-TO-FOREVER.md` (measured client facts) and
  `C:\Projects\References\forever-api-1.60.1.70205.md` (API dump). Single-owner addon: don't
  ratchet complexity.
