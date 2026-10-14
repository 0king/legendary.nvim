# AGENTS.md — legendary.nvim

Neovim Lua plugin (requires Neovim ≥ 0.7). Entrypoints: `lua/legendary/init.lua` (`setup()`, `find()`, `keymaps()/commands()/autocmds()/funcs()/itemgroups()` + singular forms) and `plugin/legendary.lua` (binds `:Legendary` cmds).

## Commands (verified in `Makefile` / CI)

- Full test suite (auto-clones `vendor/plenary.nvim`, `luassert`, `sqlite`): `make test`
  - Underlying: `nvim --headless --noplugin -u tests/testrc.lua -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/testrc.lua' }"`
  - Single spec (plenary pattern, same harness): `nvim --headless --noplugin -u tests/testrc.lua -c "PlenaryBustedFile tests/legendary/data/keymap_spec.lua"`
- Lint + format: `make check` → `luacheck lua/legendary/ tests/` + `stylua lua/ tests/`
  - CI (`lint.yml`) instead enforces `stylua --check lua/ tests/` (v0.15.2) + same luacheck args, on nightly Neovim + Lua 5.1.5. Note: `check-stylua` is a no-op when `$CI` is set — run stylua explicitly in CI-like envs.
- Dev env: `flake.nix` provides `stylua`, `luacheck`, `lemmy-help`; enter via `direnv allow` / `nix develop` (`.envrc` = `use flake`).

## Architecture

- `lua/legendary/init.lua` — lazy-loads everything via `legendary.vendor.lazy`; `find()` defers builtin loading (`lazy_load_stuff()`), so builtins/`api/cmds` only exist after first `find()`.
- `lua/legendary/data/` — item model: `keymap.lua`, `command.lua`, `augroup.lua`/`autocmd.lua`, `function.lua`, `itemgroup.lua`, `itemlist.lua`, `state.lua` (global store), `builtins.lua` (large, only loaded when `include_builtin`).
- `lua/legendary/api/` (`cmds`, `executor`), `ui/` (finder/`format.lua`), `extensions/` (one module per plugin, e.g. `lazy_nvim`, `which_key`), `config.lua`, `toolbox.lua`, `filters.lua`.
- Tests live in `tests/legendary/**/*_spec.lua` (plenary busted + `luassert`); `tests/testrc.lua` sets `rtp` to repo + vendors.

## Conventions / gotchas

- Style: `stylua.toml` = spaces, width 2, `AutoPreferSingle`; `.luacheckrc` globals `vim`, ignores `lua/legendary/vendor/*.lua`. Keep `lua/legendary/vendor/lazy.lua` untouched.
- Docs are generated — edit Markdown sources, never `doc/*.txt` by hand:
  - `make gen-vimdoc` regenerates `doc/*.txt` from `doc/*.md`/`README.md` via treesitter + `ts-vimdoc.nvim` (CI opens an auto-PR on master push).
  - `make api-docs` regenerates `doc/legendary-api.txt` via `lemmy-help` over `init.lua`, `filters.lua`, `toolbox.lua`, `ui/format.lua`, `extensions/init.lua`.
- Item tables are parsed then `:apply()`ed (`Keymap:parse(tbl):apply()`); description-only keymaps carry no implementation (see `keymap_spec.lua`).
- `CONTRIBUTING.md` is stale on one point: the real Makefile target is `make lsp-addon` (not `make lsp-addons`).
- PRs: use [conventional-commits](https://www.conventionalcommits.org/) titles (changelog is generated); PR template requires testing notes + regression checklist (keymaps/commands/autocmds across normal/insert/visual modes).
