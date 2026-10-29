# Changes README — legendary.nvim

Record of every change made in this repository during the last 15 days.

- **Window:** 2026-10-14 → 2026-10-29
- **Branch:** `master`
- **Commits in window:** 7 (`918b11c` → `bf4995d`)
- **Working tree at time of writing:** 13 modified files + 1 new test file, not yet committed
- **Themes:** universal command palette, builtin catalogues, explorer/layout actions, generated docs, tests, contributor rules

## Commit index

| Date | Commit | Type | Summary |
| --- | --- | --- | --- |
| 2026-10-29 | `bf4995d` | docs | Update `AGENTS.md` with the "Local LazyVim config — hands off" rules |
| 2026-10-28 | `60a9b66` | fix | Expose explorer actions while editing; make "Focus editor" a no-op in editor windows |
| 2026-10-27 | `b1395c6` | feat | Add layout navigation actions and LazyVim `<leader><tab>` keymap catalogue |
| 2026-10-27 | `8d93c83` | feat | Add file-explorer actions and `snacks.explorer` keymap catalogue |
| 2026-10-14 | `1fcc705` | docs | Add `AGENTS.md` contributor guide |
| 2026-10-14 | `353f11e` | feat | Universal command palette with keywords, categories and builtin actions |
| 2026-10-14 | `918b11c` | docs | Add the universal command palette plan |

---

## 2026-10-29 — Working tree (uncommitted): catalogue markers

Adds a visual way to distinguish hand-written shortcut catalogues from real,
user-owned keymaps.

### Code

- **`lua/legendary/data/keymap.lua`**
  - Added optional `marker` field to the `Keymap` class (`---@field marker string|nil`).
  - `Keymap:parse()` validates it as an optional string and copies it to the instance.
- **`lua/legendary/ui/format.lua`**
  - `M.default_format()` now prepends `item.marker` to the mode/type column.
  - With a custom `Config.icons.keymap`, the marker is placed before the icon
    (for example `🏡 K`); without an icon the column becomes `🏡 n`.
  - Keymaps without a marker render exactly as before.
- **`lua/legendary/init.lua`**
  - Added `BUILTIN_KEYMAP_MARKER = '🏡'`.
  - Builtin keymaps loaded from `legendary.data.builtins` get `🏡` by default
    (unless the item already defines its own marker).
- **`lua/legendary/data/explorer.lua`**
  - Added `CATALOGUE_MARKER = '👉'`; every catalogue keymap now carries it.
- **`lua/legendary/data/layout.lua`**
  - Added `CATALOGUE_MARKER = '👉'`; every catalogue keymap now carries it.

### Docs

- **`README.md`** — new paragraph explaining `🏡` (builtin keymap catalogue) and
  `👉` (explorer/layout catalogues), and that `marker` is available to custom keymaps.
- **`doc/table_structures/KEYMAPS.md`** — new "Catalogue markers" section with an example.
- **`doc/legendary-keymap-tables.txt`** — regenerated: new TOC entries plus
  "Search keywords and categories (command palette)" and "Catalogue markers" sections.
- **`doc/legendary.txt`** — regenerated: palette/explorer/layout/marker documentation,
  the upstream maintainer note, and an updated "Last change" date.
- **`doc/tags`** — new `legendary-keymap-tables-catalogue-markers` tag.

### Tests

- **`tests/legendary/ui/format_spec.lua`** (new, 3 cases)
  - Marker prefixes the mode column.
  - Keymaps without a marker are unchanged.
  - A custom `Config.icons.keymap` stays after the marker (`🏡 K`).
- **`tests/legendary/data/keymap_spec.lua`** — parsing preserves an optional marker.
- **`tests/legendary/data/explorer_spec.lua`** — explorer keymaps carry `👉`.
- **`tests/legendary/data/layout_spec.lua`** — layout keymaps carry `👉`.

---

## 2026-10-29 — `bf4995d` docs: update AGENTS.md

- Added a **"Local LazyVim config — hands off"** section to `AGENTS.md`.
- Explicitly forbids:
  - symlinking this repository into `~/.config/nvim`;
  - copying/rsyncing plugin changes there;
  - adding `dev = { path = ... }` / `dev = true` entries to LazyVim specs;
  - editing `lazy-lock.json`;
  - running `:Lazy sync`, `:Lazy update`, or `:Lazy restore` against that config.
- States that the user applies all updates to their own config, and that this repo
  is developed and tested standalone (`make test`, `tests/testrc.lua`).

---

## 2026-10-28 — `60a9b66` fix: expose explorer actions while editing

### Problem

The explorer selection filters only matched the palette's own buffer. Opening the
palette from an editor window hid **25 of 30** explorer actions even while a
`snacks.explorer` was open.

### Fix

- **`lua/legendary/data/explorer.lua`**
  - `is_explorer_context()` now returns true whenever a `snacks.explorer` picker is
    open, instead of requiring the palette buffer to be the explorer's list/input/preview buffer.
  - Snacks actions resolve the picker themselves, so they work with the cursor in an
    editor window and act on the explorer's own selection.
  - `nvim-tree.nvim` actions remain restricted to the tree buffer because its API
    acts on the tree cursor.
- **`lua/legendary/data/layout.lua`**
  - `focus_editor()` is now a no-op when focus is already in an editor window; it no
    longer jumps to `picker.main` (which could be an unrelated split).
  - Still prefers the previously focused editor window, then any editor window in the
    current tab page.

### Docs and tests

- **`README.md`** — clarified when explorer-selection actions are available for
  `snacks.nvim` vs `nvim-tree.nvim`, and the "Focus editor" no-op behaviour.
- **`tests/legendary/data/explorer_spec.lua`** — added coverage for selection actions
  being available with an open snacks explorer.
- **`tests/legendary/data/layout_spec.lua`** — added 38 lines covering focus behaviour,
  including not jumping to `picker.main` when already in an editor window and leaving
  a floating window when focusing the editor.

---

## 2026-10-27 — `b1395c6` feat: layout navigation action and keymap catalogue

- **New module `lua/legendary/data/layout.lua`**
  - **5 executable actions** (category `Layout`):
    - Focus next tab
    - Focus previous tab
    - Focus first tab
    - Focus last tab
    - Focus editor (moved here from the explorer catalogue so it works from any layout window)
  - **7 description-only keymaps** mirroring LazyVim's default `<leader><tab>` bindings:
    - `<leader><tab>]` / `<leader><tab>[` — next/previous tab
    - `<leader><tab>f` / `<leader><tab>l` — first/last tab
    - `<leader><tab><tab>` — new tab
    - `<leader><tab>d` / `<leader><tab>o` — close current/other tabs
  - A filter hides each keymap unless its binding actually exists (`vim.fn.maparg`), so
    the catalogue stays valid outside LazyVim and after a custom leader change.
  - Legendary never binds these mappings itself.
- **`lua/legendary/init.lua`** — registers layout actions and keymaps under
  `include_builtin = true`.
- **`README.md`** — documents the layout catalogue and the conditional keymap visibility.
- **`tests/legendary/data/layout_spec.lua`** (new, 157 lines) — catalogue metadata,
  parsing, binding-presence filter, tab focus, focus-editor behaviour, and floating-window handling.

---

## 2026-10-27 — `8d93c83` feat: file explorer action and keymap catalogue

- **New module `lua/legendary/data/explorer.lua`**
  - **30 executable actions** (category `Explorer`) for `snacks.nvim` and `nvim-tree.nvim`:
    - Focus/toggle explorer, reveal current file, toggle hidden/ignored files
    - Refresh, collapse all, go to parent directory
    - Create, rename, delete, copy, move, paste, yank path, open with system app
    - Snacks-only: grep in directory, open terminal, set tab cwd, toggle preview/follow/maximize
    - Git next/previous hunk, diagnostics next/previous, warnings/errors next/previous
  - **38 description-only keymaps** for the default `snacks.explorer` bindings:
    - Open/collapse/navigate: `<CR>`, `l`, `h`, `<BS>`, `.`, `/`, `q`
    - File operations: `a`, `d`, `r`, `c`, `m`, `p`, `y`, `o`, `u`
    - Splits/terminal: `<C-s>`, `<C-v>`, `<C-t>`, `<C-c>`
    - Filters/toggles: `H`, `I`, `P`, `Z`, `<M-h>`, `<M-i>`, `<M-p>`, `<M-f>`, `<M-m>`
    - Git/diagnostics: `]g`, `[g`, `]d`, `[d`, `]w`, `[w`, `]e`, `[e`
    - Help: `?`
  - Keymaps are filtered to the `snacks.explorer` buffer and are never bound by legendary.
- **`lua/legendary/api/executor.lua`**
  - Before feeding keys for a filtered keymap, restore the context buffer's window.
    This matters when the picker closes with focus in a different window.
- **`lua/legendary/init.lua`** — registers explorer keymaps (parsed as non-builtin to
  preserve remapping) and actions under `include_builtin = true`.
- **`README.md`** — documents the explorer catalogue, supported plugins, and bindings.
- **`tests/legendary/data/explorer_spec.lua`** (new, 111 lines) — catalogue metadata,
  parsing, no `<leader>` bindings, explorer-buffer filter.
- **`tests/legendary/data/keymap_spec.lua`** — added 29 lines covering catalogue parsing.

---

## 2026-10-14 — `353f11e` feat: universal command palette

### Item metadata: `keywords` and `category`

- **`lua/legendary/data/keymap.lua`, `command.lua`, `function.lua`, `autocmd.lua`**
  - Accept `keywords` (string or list of strings) and `category` (string).
  - Store both on the parsed item.
  - Include keywords in `id()` and `frecency_id()` so deduplication and frecency see them.
  - Add `search_text()` returning keys/events/cmd + description + category + keywords.
- **`lua/legendary/util/init.lua`**
  - `M.get_keywords(item)` normalizes a string to a list and defaults to `{}`.
  - `M.get_category(item)` returns the category.
- **`lua/legendary/ui/format.lua`**
  - New `M.search_text(item)` helper (safe `pcall` around `item:search_text()`).
  - Descriptions are displayed as `Description [Category] (keyword1, keyword2)` for
    keymaps, commands, autocmds and functions.
  - The decorated text is part of `format_item()` output, so any `vim.ui.select()`
    picker fuzzy-matches on concepts such as `copy`, `fold all`, `duplicate line`, `uppercase`.
  - Items without metadata render exactly as before.

### Palette entry points

- **`lua/legendary/api/cmds.lua`**
  - New `:CommandPalette` command — opens the unified palette with all keymaps,
    commands, functions and autocmds (including builtins).
  - `:Legendary palette` is accepted and completed as an alias for the unified palette.
- **`README.md`** — documents `:CommandPalette` and VS Code-like bindings for normal,
  visual and insert modes (`<C-S-P>`, `<C-p>`, `<leader>sp`), including the note that
  some terminals send `<C-S-P>` as `<C-p>`.

### Executable palette actions

- **New module `lua/legendary/data/palette_actions.lua`** — 28 action commands with
  descriptions, categories and keywords:
  - Clipboard: `:Copy`, `:Cut`, `:Paste`, `:SelectAll`
  - Lines: `:DeleteLine`, `:JoinLines`, `:SortLines`, `:SortLinesReverse`,
    `:TrimWhitespace`, `:MoveLineDown`, `:MoveLineUp`, `:DuplicateLineDown`,
    `:DuplicateLineUp`
  - Case: `:Uppercase`, `:Lowercase`, `:ToggleCase`
  - Folds: `:ToggleFold`, `:FoldAll`, `:UnfoldAll`
  - Windows/tabs/files: `:SplitHorizontal`, `:SplitVertical`, `:CloseWindow`,
    `:CloseOtherWindows`, `:NewTab`, `:CloseTab`, `:SaveAll`
  - Editing: `:Format`, `:ToggleComment`
- **`lua/legendary/init.lua`**
  - Loads the actions lazily on the first `find()`.
  - Applies each as a real user command, wrapped in `pcall` so a user-defined command
    with the same name wins instead of causing an error.

### Expanded builtin catalogue

- **`lua/legendary/data/builtins.lua`**
  - Now **272 builtin keymaps** and **103 builtin commands**, all annotated with
    `category` and searchable `keywords`.
  - Categories include: Buffer, Case, Clipboard, Comment, Complete, Diff, Edit, File,
    Fold, Format, Git, Help, LSP, Line, Macro, Navigation, Option, Quickfix, Register,
    Search, Select, Session, Spelling, Tab, View, Window.
  - Notable additions/improvements:
    - Visual-mode clipboard entries (`y`, `"+y`, `p` in `x` mode).
    - Line/clipboard operators (`dd`, `Y`, `D`, `C`), text objects, case operators.
    - Fold keys (`za`, `zM`, `zR`, `zi`, ...), window/split keys, `gcc` comments.
    - Line moves/duplicates (`<A-j>`, `<A-k>` and visual variants).
    - LSP, Git hunk, file, tab, buffer, search, quickfix and diff commands.
    - Fixed duplicate `~` entry.
    - Human-readable descriptions for builtin Ex commands (`:w`, `:q`, `:sort`, ...).

### Documentation

- **`README.md`** — palette overview and usage.
- **`doc/table_structures/COMMANDS.md`** — "Search keywords and categories" section.
- **`doc/table_structures/FUNCTIONS.md`** — same for functions.
- **`doc/table_structures/KEYMAPS.md`** — same for keymaps.

---

## 2026-10-14 — `1fcc705` docs: add AGENTS.md contributor guide

- Added `AGENTS.md` (29 lines) covering:
  - Verified commands (`make test`, `make check`, single-spec invocation, `flake.nix`).
  - Architecture map (`init.lua`, `data/`, `api/`, `ui/`, `extensions/`, tests).
  - Conventions: stylua/luacheck, generated docs (`make gen-vimdoc`, `make api-docs`),
    item parse/apply model, the stale `make lsp-addon` note, and conventional-commit PRs.

---

## 2026-10-14 — `918b11c` docs: add universal command palette plan

- Added `COMMAND_PALETTE_PLAN.md` (101 lines) describing the design for a VS Code-like
  command palette:
  - Goal: expose all editor capabilities by human-readable concept.
  - Findings/gaps in the existing implementation.
  - Proposed core changes (builtins, keywords/categories, formatter, `:CommandPalette`).
  - Proposed LazyVim integration and verification steps.

---

## Files changed in the window

| File | Change |
| --- | --- |
| `AGENTS.md` | Added contributor guide; later added LazyVim "hands off" rules |
| `COMMAND_PALETTE_PLAN.md` | New palette design document |
| `README.md` | Palette, explorer, layout and marker documentation |
| `doc/table_structures/COMMANDS.md` | `keywords`/`category` docs |
| `doc/table_structures/FUNCTIONS.md` | `keywords`/`category` docs |
| `doc/table_structures/KEYMAPS.md` | `keywords`/`category` and marker docs |
| `doc/legendary.txt` | Regenerated vimdoc |
| `doc/legendary-keymap-tables.txt` | Regenerated vimdoc |
| `doc/tags` | New marker help tag |
| `lua/legendary/api/cmds.lua` | `:CommandPalette`, `:Legendary palette` |
| `lua/legendary/api/executor.lua` | Restore context buffer for filtered keymaps |
| `lua/legendary/data/autocmd.lua` | `keywords`/`category`, `search_text()` |
| `lua/legendary/data/builtins.lua` | Expanded builtin catalogue with metadata |
| `lua/legendary/data/command.lua` | `keywords`/`category`, `search_text()` |
| `lua/legendary/data/explorer.lua` | New explorer catalogue; context fix; `👉` marker |
| `lua/legendary/data/function.lua` | `keywords`/`category`, `search_text()` |
| `lua/legendary/data/keymap.lua` | `keywords`/`category`, `search_text()`, `marker` |
| `lua/legendary/data/layout.lua` | New layout catalogue; focus fix; `👉` marker |
| `lua/legendary/data/palette_actions.lua` | New 28-command action catalogue |
| `lua/legendary/init.lua` | Lazy registration of actions/catalogues; `🏡` marker |
| `lua/legendary/ui/format.lua` | Searchable descriptions; marker column |
| `lua/legendary/util/init.lua` | `get_keywords()`, `get_category()` |
| `tests/legendary/data/explorer_spec.lua` | New/updated explorer coverage |
| `tests/legendary/data/keymap_spec.lua` | Catalogue parsing and marker coverage |
| `tests/legendary/data/layout_spec.lua` | New/updated layout coverage |
| `tests/legendary/ui/format_spec.lua` | New formatter/marker coverage (uncommitted) |

## Testing and verification

Per `AGENTS.md`, verify with:

```sh
make test    # full plenary suite
make check   # luacheck + stylua
```

Single spec:

```sh
nvim --headless --noplugin -u tests/testrc.lua \
  -c "PlenaryBustedFile tests/legendary/ui/format_spec.lua"
```

## Notes

- `doc/legendary.txt`, `doc/legendary-keymap-tables.txt` and `doc/tags` are generated
  artifacts; edit the Markdown sources in `doc/` and `README.md`, then regenerate.
- The working-tree marker changes are **not committed** as of this record. Commit them
  separately from this document if desired.
- The upstream maintainer note visible in `doc/legendary.txt` comes from the existing
  `README.md` header and was picked up by the vimdoc regeneration.
