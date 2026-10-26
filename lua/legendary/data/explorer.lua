-- Hand-written catalogue of common file-explorer actions and keymaps.
--
-- Global actions (open/toggle the explorer, reveal the current file, toggle
-- hidden/ignored files) are executable from any buffer and adapt to the
-- explorer that is available: snacks.explorer is preferred, with nvim-tree as
-- a fallback for the operations it exposes. Actions that operate on the
-- explorer's current selection or focus are filtered to the explorer buffer.
-- The keymaps are description-only entries for the default snacks.explorer
-- bindings. They are filtered to the explorer buffer so they only show up when
-- the palette is opened from the file tree, and legendary never binds them
-- itself.
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

---@return table|nil
local function get_nvim_tree()
  local ok, api = pcall(require, 'nvim-tree.api')
  if ok then
    return api
  end
  return nil
end

---@return boolean
local function nvim_tree_is_open()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'NvimTree' then
      return true
    end
  end
  return false
end

---@param picker snacks.Picker
---@param part 'list'|'input'|'preview'
---@return integer|nil
local function picker_buf(picker, part)
  local section = picker and picker[part]
  return section and section.win and section.win.buf or nil
end

---Filter keymaps down to the snacks.explorer list buffer.
---@param _ LegendaryItem
---@param context LegendaryEditorContext
---@return boolean
local function is_snacks_explorer(_, context)
  if not context or not context.buf then
    return false
  end
  return picker_buf(get_snacks_explorer(), 'list') == context.buf
end

---Filter actions that operate on the explorer's current selection down to the
---explorer itself. Global actions such as focus/toggle stay available anywhere.
---@param _ LegendaryItem
---@param context LegendaryEditorContext
---@return boolean
local function is_explorer_context(_, context)
  if not context or not context.buf then
    return false
  end
  if context.filetype == 'NvimTree' then
    return true
  end
  local picker = get_snacks_explorer()
  if not picker then
    return false
  end
  local list_buf = picker_buf(picker, 'list')
  local input_buf = picker_buf(picker, 'input')
  local preview_buf = picker_buf(picker, 'preview')
  return context.buf == list_buf or context.buf == input_buf or context.buf == preview_buf
end

---Resolve a snacks action name (including nested action tables) to a callable.
---@param picker snacks.Picker
---@param name string
---@return fun(picker:snacks.Picker, item?:table)|nil
local function resolve_snacks_action(picker, name)
  local ok, config = pcall(require, 'snacks.picker.config')
  if not ok then
    return nil
  end
  local spec = config.action(picker, name)
  if type(spec) == 'function' then
    return spec
  end
  if type(spec) == 'table' then
    local inner = spec.action
    if type(inner) == 'function' then
      return function(p, item)
        return inner(p, item, spec)
      end
    elseif type(inner) == 'string' then
      local resolved = resolve_snacks_action(picker, inner)
      if resolved then
        return function(p, item)
          return resolved(p, item, spec)
        end
      end
    end
  end
  return nil
end

---@param picker snacks.Picker
---@param name string
---@return boolean
local function run_snacks_action(picker, name)
  local fn = resolve_snacks_action(picker, name)
  if not fn then
    notify(('Explorer action %q is not available.'):format(name))
    return false
  end
  local ok, err = pcall(fn, picker, picker:current())
  if not ok then
    notify(('Explorer action %q failed: %s'):format(name, err), vim.log.levels.ERROR)
    return false
  end
  return true
end

---Run a snacks action, falling back to the matching nvim-tree API call.
---@param name string
---@param nvim_tree_fn? fun(api:table)
---@return boolean
local function run_explorer_action(name, nvim_tree_fn)
  local picker = get_snacks_explorer()
  if picker then
    return run_snacks_action(picker, name)
  end
  if nvim_tree_fn then
    local api = get_nvim_tree()
    if api then
      local ok, err = pcall(nvim_tree_fn, api)
      if ok then
        return true
      end
      notify(('Explorer action failed: %s'):format(err), vim.log.levels.ERROR)
      return false
    end
  end
  notify('No file explorer is open.')
  return false
end

---Run an action that only snacks.explorer implements.
---@param name string
---@return boolean
local function run_snacks_only_action(name)
  local picker = get_snacks_explorer()
  if picker then
    return run_snacks_action(picker, name)
  end
  if nvim_tree_is_open() then
    notify('This action is only supported with snacks.explorer.')
  else
    notify('No file explorer is open.')
  end
  return false
end

---@return boolean
local function focus_explorer()
  local picker = get_snacks_explorer()
  if picker then
    picker:focus('list', { show = true })
    return true
  end
  local Snacks = snacks()
  if Snacks then
    local ok, err = pcall(Snacks.explorer, { focus = 'list' })
    if ok then
      return true
    end
    notify(('Failed to open explorer: %s'):format(err), vim.log.levels.ERROR)
    return false
  end
  local api = get_nvim_tree()
  if api then
    local ok, err = pcall(api.tree.open)
    if ok then
      return true
    end
    notify(('Failed to open nvim-tree: %s'):format(err), vim.log.levels.ERROR)
    return false
  end
  notify('No supported file explorer found. Install snacks.nvim or nvim-tree.nvim.')
  return false
end

---@return boolean
local function toggle_explorer()
  local picker = get_snacks_explorer()
  if picker then
    picker:close()
    return true
  end
  local Snacks = snacks()
  if Snacks then
    local ok, err = pcall(Snacks.explorer)
    if ok then
      return true
    end
    notify(('Failed to open explorer: %s'):format(err), vim.log.levels.ERROR)
    return false
  end
  local api = get_nvim_tree()
  if api then
    local ok, err = pcall(api.tree.toggle, { focus = true })
    if ok then
      return true
    end
    notify(('Failed to toggle nvim-tree: %s'):format(err), vim.log.levels.ERROR)
    return false
  end
  notify('No supported file explorer found. Install snacks.nvim or nvim-tree.nvim.')
  return false
end

---@return string|nil
local function current_file()
  local buf = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[buf].filetype

  if filetype == 'snacks_picker_list' or filetype == 'snacks_picker_input' then
    local picker = get_snacks_explorer()
    local item = picker and picker:current()
    return item and item.file or nil
  end

  if filetype == 'NvimTree' or filetype == 'neo-tree' or filetype == 'oil' then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(buf)
  if name ~= '' then
    return name
  end
  return nil
end

---@return boolean
local function reveal_current_file()
  local file = current_file()
  if not file then
    notify('Current buffer is not a file.')
    return false
  end

  local Snacks = snacks()
  if Snacks then
    local ok, err = pcall(Snacks.explorer.reveal, { file = file })
    if ok then
      return true
    end
    notify(('Failed to reveal file: %s'):format(err), vim.log.levels.ERROR)
    return false
  end

  local api = get_nvim_tree()
  if api then
    local ok, err = pcall(api.tree.find_file, { buf = file, open = true, focus = true })
    if ok then
      return true
    end
    notify(('Failed to reveal file: %s'):format(err), vim.log.levels.ERROR)
    return false
  end

  notify('No supported file explorer found. Install snacks.nvim or nvim-tree.nvim.')
  return false
end

---@param option 'hidden'|'ignored'
---@return boolean
local function toggle_snacks_filter(option)
  local picker = get_snacks_explorer()
  if picker then
    return run_snacks_action(picker, 'toggle_' .. option)
  end

  local Snacks = snacks()
  if Snacks then
    local value = true
    local ok, config = pcall(function()
      return require('snacks.picker.config').get({ source = 'explorer' })
    end)
    if ok and config then
      value = not config[option]
    end
    local opened, err = pcall(Snacks.explorer, { [option] = value })
    if opened then
      return true
    end
    notify(('Failed to open explorer: %s'):format(err), vim.log.levels.ERROR)
    return false
  end

  local api = get_nvim_tree()
  if api then
    local fn = option == 'hidden' and api.filter.dotfiles.toggle or api.filter.git.ignored.toggle
    local ok, err = pcall(fn)
    if ok then
      pcall(api.tree.open)
      return true
    end
    notify(('Failed to toggle %s files: %s'):format(option, err), vim.log.levels.ERROR)
    return false
  end

  notify('No supported file explorer found. Install snacks.nvim or nvim-tree.nvim.')
  return false
end

---@return boolean
local function refresh_explorer()
  return run_explorer_action('explorer_update', function(api)
    api.tree.reload()
  end)
end

---@return boolean
local function collapse_all()
  return run_explorer_action('explorer_close_all', function(api)
    api.tree.collapse_all()
  end)
end

---@return boolean
local function parent_directory()
  return run_explorer_action('explorer_up', function(api)
    api.tree.change_root_to_parent()
  end)
end

---@return boolean
local function create_file()
  return run_explorer_action('explorer_add', function(api)
    api.fs.create()
  end)
end

---@return boolean
local function rename_file()
  return run_explorer_action('explorer_rename', function(api)
    api.fs.rename()
  end)
end

---@return boolean
local function delete_file()
  return run_explorer_action('explorer_del', function(api)
    api.fs.remove()
  end)
end

---@return boolean
local function copy_file()
  return run_explorer_action('explorer_copy', function(api)
    api.fs.copy.node()
  end)
end

---@return boolean
local function move_file()
  return run_explorer_action('explorer_move', function(api)
    api.fs.cut()
  end)
end

---@return boolean
local function paste_file()
  return run_explorer_action('explorer_paste', function(api)
    api.fs.paste()
  end)
end

---@return boolean
local function yank_path()
  return run_explorer_action('explorer_yank', function(api)
    api.fs.copy.absolute_path()
  end)
end

---@return boolean
local function open_external()
  return run_explorer_action('explorer_open', function(api)
    api.node.run.system()
  end)
end

---@return boolean
local function git_next()
  return run_explorer_action('explorer_git_next', function(api)
    api.node.navigate.git.next()
  end)
end

---@return boolean
local function git_prev()
  return run_explorer_action('explorer_git_prev', function(api)
    api.node.navigate.git.prev()
  end)
end

---@return boolean
local function diagnostic_next()
  return run_explorer_action('explorer_diagnostic_next', function(api)
    api.node.navigate.diagnostics.next()
  end)
end

---@return boolean
local function diagnostic_prev()
  return run_explorer_action('explorer_diagnostic_prev', function(api)
    api.node.navigate.diagnostics.prev()
  end)
end

---@param fn fun():boolean
---@param description string
---@param keywords string[]
---@param requires_explorer? boolean
---@return table
local function explorer_action(fn, description, keywords, requires_explorer)
  local all_keywords = { 'explorer' }
  vim.list_extend(all_keywords, keywords)
  return {
    fn,
    description = description,
    category = 'Explorer',
    keywords = all_keywords,
    filters = requires_explorer and { is_explorer_context } or nil,
  }
end

---@param name string
---@param description string
---@param keywords string[]
---@return table
local function snacks_only_action(name, description, keywords)
  return explorer_action(function()
    return run_snacks_only_action(name)
  end, description, keywords, true)
end

M.actions = {
  explorer_action(focus_explorer, 'Focus explorer', { 'focus', 'open', 'file', 'tree', 'sidebar' }),
  explorer_action(toggle_explorer, 'Toggle explorer', { 'toggle', 'open', 'close', 'file', 'tree', 'sidebar' }),
  explorer_action(
    reveal_current_file,
    'Reveal current file in explorer',
    { 'reveal', 'current', 'file', 'find', 'locate' }
  ),
  explorer_action(function()
    return toggle_snacks_filter('hidden')
  end, 'Toggle hidden files in explorer', { 'hidden', 'dotfiles', 'show', 'hide', 'files' }),
  explorer_action(function()
    return toggle_snacks_filter('ignored')
  end, 'Toggle ignored files in explorer', { 'ignored', 'gitignore', 'show', 'hide', 'files' }),
  explorer_action(refresh_explorer, 'Refresh explorer', { 'refresh', 'reload', 'update' }, true),
  explorer_action(
    collapse_all,
    'Collapse all directories in explorer',
    { 'collapse', 'close', 'directories', 'folders', 'all' },
    true
  ),
  explorer_action(
    parent_directory,
    'Go to parent directory in explorer',
    { 'parent', 'up', 'directory', 'folder' },
    true
  ),
  explorer_action(create_file, 'Create file or directory in explorer', { 'create', 'new', 'file', 'directory' }, true),
  explorer_action(rename_file, 'Rename file or directory in explorer', { 'rename', 'file', 'directory' }, true),
  explorer_action(
    delete_file,
    'Delete file or directory in explorer',
    { 'delete', 'remove', 'file', 'directory' },
    true
  ),
  explorer_action(copy_file, 'Copy file or directory in explorer', { 'copy', 'file', 'directory' }, true),
  explorer_action(move_file, 'Move file or directory in explorer', { 'move', 'cut', 'file', 'directory' }, true),
  explorer_action(paste_file, 'Paste file or directory in explorer', { 'paste', 'file', 'directory' }, true),
  explorer_action(yank_path, 'Yank file path in explorer', { 'yank', 'copy', 'path', 'file' }, true),
  explorer_action(
    open_external,
    'Open file with system application in explorer',
    { 'open', 'system', 'external', 'application' },
    true
  ),
  snacks_only_action('picker_grep', 'Grep in explorer directory', { 'grep', 'search', 'directory', 'folder', 'find' }),
  snacks_only_action('terminal', 'Open terminal in explorer directory', { 'terminal', 'shell', 'directory', 'folder' }),
  snacks_only_action(
    'tcd',
    'Set tab working directory to explorer directory',
    { 'tab', 'cwd', 'working', 'directory' }
  ),
  snacks_only_action('toggle_preview', 'Toggle preview in explorer', { 'preview', 'toggle', 'show', 'hide' }),
  snacks_only_action(
    'toggle_follow',
    'Toggle follow current file in explorer',
    { 'follow', 'current', 'file', 'toggle' }
  ),
  snacks_only_action('toggle_maximize', 'Toggle maximize explorer', { 'maximize', 'toggle', 'window' }),
  explorer_action(git_next, 'Go to next git change in explorer', { 'git', 'next', 'change', 'hunk' }, true),
  explorer_action(git_prev, 'Go to previous git change in explorer', { 'git', 'previous', 'change', 'hunk' }, true),
  explorer_action(
    diagnostic_next,
    'Go to next diagnostic in explorer',
    { 'diagnostic', 'next', 'error', 'warning' },
    true
  ),
  explorer_action(
    diagnostic_prev,
    'Go to previous diagnostic in explorer',
    { 'diagnostic', 'previous', 'error', 'warning' },
    true
  ),
  snacks_only_action('explorer_warn_next', 'Go to next warning in explorer', { 'warning', 'next', 'diagnostic' }),
  snacks_only_action(
    'explorer_warn_prev',
    'Go to previous warning in explorer',
    { 'warning', 'previous', 'diagnostic' }
  ),
  snacks_only_action('explorer_error_next', 'Go to next error in explorer', { 'error', 'next', 'diagnostic' }),
  snacks_only_action('explorer_error_prev', 'Go to previous error in explorer', { 'error', 'previous', 'diagnostic' }),
}

---@param lhs string
---@param description string
---@param keywords string[]
---@param opts? table
---@return table
local function explorer_keymap(lhs, description, keywords, opts)
  local all_keywords = { 'explorer' }
  vim.list_extend(all_keywords, keywords)
  opts = opts or {}
  return {
    lhs,
    description = description,
    category = 'Explorer',
    keywords = all_keywords,
    mode = opts.mode,
    filters = { is_snacks_explorer },
  }
end

M.keymaps = {
  explorer_keymap('<CR>', 'Open file or directory', { 'open', 'file', 'directory', 'confirm' }),
  explorer_keymap('l', 'Open file or directory', { 'open', 'file', 'directory', 'confirm' }),
  explorer_keymap('h', 'Collapse directory', { 'collapse', 'close', 'directory', 'folder' }),
  explorer_keymap('<BS>', 'Go to parent directory', { 'parent', 'up', 'directory', 'folder' }),
  explorer_keymap('.', 'Set explorer root to current directory', { 'focus', 'root', 'directory', 'cwd' }),
  explorer_keymap('a', 'Create file or directory', { 'create', 'new', 'file', 'directory' }),
  explorer_keymap('d', 'Delete file or directory', { 'delete', 'remove', 'file', 'directory' }),
  explorer_keymap('r', 'Rename file or directory', { 'rename', 'file', 'directory' }),
  explorer_keymap('c', 'Copy file or directory', { 'copy', 'file', 'directory' }),
  explorer_keymap('m', 'Move file or directory', { 'move', 'cut', 'file', 'directory' }),
  explorer_keymap('p', 'Paste file or directory', { 'paste', 'file', 'directory' }),
  explorer_keymap('y', 'Yank file path', { 'yank', 'copy', 'path', 'file' }, { mode = { 'n', 'x' } }),
  explorer_keymap('o', 'Open with system application', { 'open', 'system', 'external', 'application' }),
  explorer_keymap('u', 'Refresh explorer', { 'refresh', 'reload', 'update' }),
  explorer_keymap('<C-c>', 'Set tab working directory', { 'tab', 'cwd', 'working', 'directory' }),
  explorer_keymap('<C-t>', 'Open terminal here', { 'terminal', 'shell', 'directory' }),
  explorer_keymap('<C-s>', 'Open in horizontal split', { 'open', 'split', 'horizontal', 'window' }),
  explorer_keymap('<C-v>', 'Open in vertical split', { 'open', 'split', 'vertical', 'window' }),
  explorer_keymap('/', 'Toggle focus between search input and list', { 'focus', 'search', 'input', 'filter' }),
  explorer_keymap('H', 'Toggle hidden files', { 'hidden', 'dotfiles', 'show', 'hide', 'toggle' }),
  explorer_keymap('I', 'Toggle ignored files', { 'ignored', 'gitignore', 'show', 'hide', 'toggle' }),
  explorer_keymap('P', 'Toggle preview', { 'preview', 'toggle', 'show', 'hide' }),
  explorer_keymap('Z', 'Collapse all directories', { 'collapse', 'close', 'all', 'directories' }),
  explorer_keymap('<M-h>', 'Toggle hidden files', { 'hidden', 'dotfiles', 'show', 'hide', 'toggle' }),
  explorer_keymap('<M-i>', 'Toggle ignored files', { 'ignored', 'gitignore', 'show', 'hide', 'toggle' }),
  explorer_keymap('<M-p>', 'Toggle preview', { 'preview', 'toggle', 'show', 'hide' }),
  explorer_keymap('<M-f>', 'Toggle follow current file', { 'follow', 'current', 'file', 'toggle' }),
  explorer_keymap('<M-m>', 'Toggle maximize', { 'maximize', 'toggle', 'window' }),
  explorer_keymap(']g', 'Go to next git change', { 'git', 'next', 'change', 'hunk' }),
  explorer_keymap('[g', 'Go to previous git change', { 'git', 'previous', 'change', 'hunk' }),
  explorer_keymap(']d', 'Go to next diagnostic', { 'diagnostic', 'next', 'error', 'warning' }),
  explorer_keymap('[d', 'Go to previous diagnostic', { 'diagnostic', 'previous', 'error', 'warning' }),
  explorer_keymap(']w', 'Go to next warning', { 'warning', 'next', 'diagnostic' }),
  explorer_keymap('[w', 'Go to previous warning', { 'warning', 'previous', 'diagnostic' }),
  explorer_keymap(']e', 'Go to next error', { 'error', 'next', 'diagnostic' }),
  explorer_keymap('[e', 'Go to previous error', { 'error', 'previous', 'diagnostic' }),
  explorer_keymap('?', 'Show explorer keymap help', { 'help', 'keymaps', 'shortcuts' }),
  explorer_keymap('q', 'Close explorer', { 'close', 'quit', 'exit', 'cancel' }),
}

return M
