# Universal VS Code-like Command Palette via `legendary.nvim` on LazyVim

**Scope:** both `legendary.nvim` core + LazyVim wiring, provider-agnostic (`any vim.ui.select`), `y/yy/Y → "+` by default, include everything with category badges.

## 1. Goal

Complete discoverability for all editor capabilities in LazyVim:

- Everything exposed, including built-in Vim operators (`y`, `p`, `dd`, `J`, `gu`, `gU`, `~`, `>>`, `<<`), folding (`za`, `zM`, `zR`), window/split ops (`<C-w>s`, `<C-w>v`, `<C-w>o`), navigation, buffers, tabs, LSP, Git, and formatting.
- Searching via a unified Command Palette (`Ctrl+Shift+P` / `:CommandPalette` / `<leader>sp`) by human-readable concept (e.g. "copy", "toggle comment", "fold all", "move line", "uppercase", "split window", "duplicate line", "join lines", "sort", "select all"), showing the shortcut key and executing immediately.

Why built-ins are missing today:

1. Keymap pickers query only `vim.api.nvim_get_keymap()`. C-engine operators/motions (`y`, `p`, `dd`, `J`, `za`, etc.) are not in that table.
2. Built-in Ex commands (`:w`, `:q`, `:s`) have no descriptions, and many ops (copy, comment, format, move line, duplicate, fold) have no `:Command`.
3. No unified palette aggregating commands + keymaps + built-in actions.

## 2. Findings from current code

- Unified palette already exists: `lua/legendary/init.lua:109-112` `M.find(opts)` → `lua/legendary/ui/init.lua:25-103` `select_inner()` over `State.items` via `vim.ui.select()`. No filter = commands + keymaps + funcs + autocmds together.
- Builtins lazy-loaded only on first `find()`: `lua/legendary/init.lua:56-82` `lazy_load_stuff()` loads `lua/legendary/data/builtins.lua:3-389` as description-only `Keymap:parse(tbl, true)` / `Command:parse(tbl, true)`.
- Execution already works for description-only items:
  - keymap: `lua/legendary/api/executor.lua:106-107` `util.exec_feedkeys(item.keys, item.builtin)` — feeds `y, dd, J, za, zM, <C-w>s` etc.
  - command: `lua/legendary/api/executor.lua:91-105` `vim.cmd(cmd)` for builtins like `:w, :q, :sort`, `unfinished=true` prefills `:... ` via feedkeys.
  - `restore_context()` (`lua/legendary/api/executor.lua:60-79`) already supports `n/i/visual` — required for `<C-S-P>` in all modes.
- Gaps:
  1. `builtins.lua` incomplete: missing `gcc/gc/gco`, `<A-j/k>`, `<A-S-j/k>`, `<leader>cf`, `<C-h/j/k/l>`, `<S-h/l>`, `gt/gT`, LSP (`gd, gr, K, <leader>ca/cr`), Git hunks, `zi, zd, zE`, `:Copy/:ToggleComment/:MoveLineDown` etc.
  2. No searchable synonyms: `Keymap:parse` (`lua/legendary/data/keymap.lua:39-107`), `Command:parse` (`lua/legendary/data/command.lua:68-106`) only store `description`; `ui/format.lua:17-60` `default_format()` renders `mode│keys│desc` — pickers can't find `copy` → `y` unless `copy` is in `desc`. No `keywords/category` field.
  3. No first-class palette command/key: `lua/legendary/api/cmds.lua:5-174` has `:Legendary [keymaps|commands|...]` but no `:CommandPalette` alias; no `<C-S-P>` example.

## 3. Proposed changes

### A. `legendary.nvim` core (this repo)

**A1. `lua/legendary/data/builtins.lua` — expand to palette-complete:**

- Keep existing entries, add missing groups with human-concept descriptions + explicit `mode`:
  - Clipboard/select: `Y, c, cc, C, dd, ggVG, gv` (descs contain `clipboard, copy, cut, select all`).
  - Comment ops: `gcc, gc, gco, gcO` (description-only; real impl in LazyVim layer).
  - Lines: `J, gJ, >, <, ==, =, gw, <A-j/k>, <A-S-j/k>`.
  - Case: `gU, gu, gUU, guu, ~, g~` — fix duplicate `~` at `builtins.lua:90-91`.
  - Folds: `za, zo, zc, zO, zC, zA, zv, zM, zR, zm, zr, zx, zi, zd, zE, zj, zk` with `fold/close all/open all` wording.
  - Windows: `<C-w>s, v, c, o, =, _, |, H, J, K, L, h, j, k, l, w, p, T` + LazyVim `<C-h/j/k/l>, <leader>wm, uz`.
  - Buffers/tabs/nav/search/LSP/Git/UI/file: `]b/[b, <S-h/l>, gt, gT, gg, G, 0, $, zz, zt, zb, <C-d/u/o/i>, /, ?, n/N, *, #, %, gd, gr, gI, gy, K, ]d/[d, ]h/[h`.
  - Commands: `:w, :wa, :q, :qa, :e, :sp, :vsp, :tabnew, :tabc, :only, :noh, :sort, :g, :s, :norm, :bufdo, :windo, :tabdo` with `save, quit, split, sort, replace` synonyms in description.
- Convention: `description` must contain searchable nouns (`Copy line to clipboard`, `Close all folds`, `Split window vertical`).

**A2. `lua/legendary/data/keymap.lua`, `command.lua`, `function.lua`, `util/init.lua` — `keywords` + `category`:**

- Accept `tbl.keywords: string|string[]` and `tbl.category: string` in `parse()`, store on instance, include in `id()`/`frecency_id()` for dedup/scoring.
- New `util.get_keywords()` helper alongside `util.get_desc()` (`lua/legendary/util/init.lua:6-8`).

**A3. `lua/legendary/ui/format.lua` — make any picker match descriptions:**

- `default_format()` returns `{ icon, keys/cmd, description + keywords }`, e.g. `n │ yy │ Copy line to clipboard [clipboard yank]` or ` │ :ToggleFold │ Toggle fold [fold za]`.
- Ensures `telescope/dressing/snacks/fzf-lua/builtin` all fuzzy-match on concept, since they filter `format_item()` output (`lua/legendary/ui/init.lua:80-82`).
- Keep 3-column shape + `col_separator_char` for `compute_padding()` compatibility.

**A4. `lua/legendary/filters.lua`, `lua/legendary/api/cmds.lua`, `lua/legendary/api/executor.lua` — palette entrypoints:**

- Add `:CommandPalette` (alias to `find()` with no filters) + `:Legendary palette` arg for parity; keep `:Legendary keymaps/commands/functions/autocmds`.
- Verify `build_context()/restore_context()` for `i`-mode palette invocation (`startinsert` path) and `x`-mode `gv` restore.
- Document `<C-S-P>` mapping handling terminal encoding: map both `<C-S-P>` and `<C-S-p>` (many terminals send same as `<C-p>`; also note `<D-p>` on macOS, WezTerm `CTRL+SHIFT+P` passthrough).

**A5. Docs + types:**

- Edit Markdown sources only (`doc/*.md`, `README.md`), then `make gen-vimdoc` + `make api-docs` per `AGENTS.md`. Never hand-edit `doc/*.txt`.

### B. LazyVim integration (`~/.config/nvim`, via `chezmoi`)

**B1. `lua/plugins/legendary.lua` (new):**

```lua
{ 'mrjones2014/legendary.nvim', priority = 10000, lazy = false,
  opts = { include_builtin = true, include_legendary_cmds = true,
    extensions = { which_key = { auto_register = true }, lazy_nvim = true } } }
```

- `which_key` extension (`lua/legendary/extensions/which_key.lua:12-48`) auto-imports LazyVim/WK presets (operators, `z`, `<C-w>`) into palette.

**B2. `lua/config/commands.lua` (new) — only where no native Ex exists, with `range+count`:**

- `Copy/Cut/Paste/SelectAll/DeleteLine/JoinLines/Uppercase/Lowercase/ToggleCase/SortLines/TrimWhitespace/MoveLineDown/MoveLineUp/DuplicateLineDown/DuplicateLineUp/ToggleFold/FoldAll/UnfoldAll/SplitHorizontal/SplitVertical/CloseWindow/CloseOtherWindows/NewTab/CloseTab/SaveAll/Format/ToggleComment` → register via `require('legendary').commands({...})` so they appear in palette with `desc + keywords`, impl via `feedkeys` / `vim.cmd('m/t/sort')` / `vim.lsp.buf.format()` / `gc` remap. `ToggleComment` delegates to LazyVim commenter (`vim._comment` / `Comment.api` / `mini.comment` — detect at runtime).

**B3. `lua/config/keymaps.lua` (modify):**

- `require('config.commands')` first; `y, yy, Y → "+y` with descs `Copy to clipboard...` preserving `"ay` explicit register via `expr` mapping; keep existing `c/p` clipboard maps consistent.
- `<A-j/k>` desc `Move line down/up`, visual `Move selection down/up`; `<A-S-j/k>` duplicate; `<C-s>` save — add desc if missing.
- Palette keys: `vim.keymap.set({ 'n', 'x', 'i' }, '<C-S-P>', '<Cmd>CommandPalette<CR>', { desc = 'Command Palette' })` + `<leader>sp` alias.

## 4. Verification

- `make test` (or `PlenaryBustedFile tests/legendary/data/keymap_spec.lua`), `stylua --check lua/ tests/`, `luacheck lua/legendary/ tests/`.
- Headless: assert `:Copy...:CommandPalette` exist via `nvim_get_commands`, assert `y/yy/<A-j/k>/za/zM` descs via `nvim_get_keymap('n')`, execute `:MoveLineDown/:DuplicateLineUp/:Uppercase/:ToggleFold` on scratch buffer and check lines.
- Manual: `<C-S-P>` in `n/x/i` → `copy/fold all/split vertical/uppercase/duplicate` → `<Enter>` executes; `<leader>sk`-equivalent (`:Legendary keymaps`) → `fold/copy/case/window`; `:Legendary commands` → `comment/format/move/fold/sort`.

## 5. Notes / tradeoffs

- `y→"+y` overrides default yank register; explicit `"ay` still respected via expr-map.
- `<C-/>` stays as LazyVim terminal; use `gcc/gc/:ToggleComment` for comments (no remap).
- Include everything (motions/text-objects too) with category badges per request; use `itemgroups` / `category` to avoid clutter.
