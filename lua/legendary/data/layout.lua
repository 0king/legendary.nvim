-- Hand-written catalogue of layout navigation actions and keymaps.
--
-- The executable actions cover focusing tab pages and moving focus from a
-- layout window (explorer, terminal, help, quickfix, ...) back to the editor.
-- They use plain Neovim APIs and do not depend on a specific picker.
--
-- The keymaps mirror LazyVim's default `<leader><tab>` bindings and are
-- description-only: legendary never binds them. A keymap is hidden unless its
-- binding actually exists, so the entries stay valid outside LazyVim and after
-- a custom leader change.
local M = {}

---@param msg string
---@param level? integer
local function notify(msg, level)
  vim.notify('[legendary.nvim] ' .. msg, level or vim.log.levels.WARN)
end

---@return table|nil
local function snacks()
  return rawget(_G, 'Snacks')
end

---@return snacks.Picker|nil
local function get_snacks_explorer()
  if not snacks() then
    return nil
  end
  local ok, pickers = pcall(function()
    return require('snacks.picker').get({ source = 'explorer' })
  end)
  if ok and pickers and pickers[1] then
    return pickers[1]
  end
  return nil
end

---Windows that belong to the surrounding layout rather than the document
---area: file explorers, pickers, terminals, help and quickfix windows.
---@param win integer
---@return boolean
local function is_layout_window(win)
  if vim.api.nvim_win_get_config(win).relative ~= '' then
    return true
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local buftype = vim.bo[buf].buftype
  local filetype = vim.bo[buf].filetype
  if buftype == 'terminal' or buftype == 'quickfix' or buftype == 'prompt' then
    return true
  end
  if
    filetype == 'NvimTree'
    or filetype == 'neo-tree'
    or filetype == 'oil'
    or filetype == 'aerial'
    or filetype == 'trouble'
    or filetype == 'help'
    or filetype == 'snacks_terminal'
    or filetype == 'toggleterm'
    or filetype == 'lazy'
    or filetype == 'mason'
    or filetype:match('^snacks_picker_') ~= nil
  then
    return true
  end
  return vim.w[win].snacks_layout ~= nil
end

---Move focus from a layout window back to the document area. Does nothing
---when focus is already in an editor window, so it never jumps to an
---unrelated split. Prefers the window that was focused before the layout
---window, then any other editor window in the current tab page.
---@return boolean
local function focus_editor()
  local current = vim.api.nvim_get_current_win()
  if not is_layout_window(current) then
    return true
  end

  local picker = get_snacks_explorer()
  if picker and picker.main and vim.api.nvim_win_is_valid(picker.main) and picker.main ~= current then
    vim.api.nvim_set_current_win(picker.main)
    return true
  end

  local previous = vim.fn.win_getid(vim.fn.winnr('#'))
  if
    previous ~= 0
    and previous ~= current
    and vim.api.nvim_win_is_valid(previous)
    and not is_layout_window(previous)
  then
    vim.api.nvim_set_current_win(previous)
    return true
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= current and not is_layout_window(win) then
      vim.api.nvim_set_current_win(win)
      return true
    end
  end

  notify('No editor window to focus.')
  return false
end

---@param command string
---@return fun():boolean
local function focus_tab(command)
  return function()
    vim.cmd(command)
    return true
  end
end

---@param lhs string
---@param description string
---@param keywords string[]
---@return table
local function layout_keymap(lhs, description, keywords)
  local all_keywords = { 'layout' }
  vim.list_extend(all_keywords, keywords)
  return {
    lhs,
    description = description,
    category = 'Layout',
    mode = 'n',
    keywords = all_keywords,
    filters = {
      ---Hide description-only keymaps whose binding is not actually present.
      ---@param item Keymap
      ---@return boolean
      function(item)
        for _, mode in ipairs(item:modes()) do
          if vim.fn.maparg(item.keys, mode) ~= '' then
            return true
          end
        end
        return false
      end,
    },
  }
end

M.actions = {
  {
    focus_tab('tabnext'),
    description = 'Focus next tab',
    category = 'Layout',
    keywords = { 'layout', 'tab', 'next', 'focus', 'switch' },
  },
  {
    focus_tab('tabprevious'),
    description = 'Focus previous tab',
    category = 'Layout',
    keywords = { 'layout', 'tab', 'previous', 'prev', 'focus', 'switch' },
  },
  {
    focus_tab('tabfirst'),
    description = 'Focus first tab',
    category = 'Layout',
    keywords = { 'layout', 'tab', 'first', 'focus', 'switch' },
  },
  {
    focus_tab('tablast'),
    description = 'Focus last tab',
    category = 'Layout',
    keywords = { 'layout', 'tab', 'last', 'focus', 'switch' },
  },
  {
    focus_editor,
    description = 'Focus editor',
    category = 'Layout',
    keywords = { 'layout', 'editor', 'focus', 'window', 'main', 'sidebar', 'leave' },
  },
}

M.keymaps = {
  layout_keymap('<leader><tab>]', 'Focus next tab', { 'tab', 'next', 'focus', 'switch' }),
  layout_keymap('<leader><tab>[', 'Focus previous tab', { 'tab', 'previous', 'prev', 'focus', 'switch' }),
  layout_keymap('<leader><tab>f', 'Focus first tab', { 'tab', 'first', 'focus', 'switch' }),
  layout_keymap('<leader><tab>l', 'Focus last tab', { 'tab', 'last', 'focus', 'switch' }),
  layout_keymap('<leader><tab><tab>', 'Open new tab', { 'tab', 'new', 'open' }),
  layout_keymap('<leader><tab>d', 'Close current tab', { 'tab', 'close' }),
  layout_keymap('<leader><tab>o', 'Close other tabs', { 'tab', 'close', 'others', 'only' }),
}

return M
