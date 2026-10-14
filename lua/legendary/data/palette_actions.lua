-- Palette action commands shipped with legendary.nvim.
-- These cover common editor operations that have no native Ex command
-- (copy/cut/paste, move/duplicate lines, case, folds, splits, ...),
-- so the command palette can discover and execute them by concept name.
-- Loaded lazily on first `find()`; each entry is applied as a real user
-- command (guarded with pcall so user-defined versions win on collision).
local Toolbox = require('legendary.toolbox')

local function current_range(args)
  return args.line1, args.line2
end

local function is_visual()
  return Toolbox.is_visual_mode(vim.fn.mode())
end

local M = {}

M.actions = {
  {
    ':Copy',
    function(args)
      local line1, line2 = current_range(args)
      if args.count and args.count > 0 and args.range == 0 then
        line2 = line1 + args.count - 1
      end
      vim.cmd(string.format('silent %d,%dyank +', line1, line2))
    end,
    description = 'Copy to clipboard',
    keywords = { 'copy', 'yank', 'clipboard' },
    category = 'Clipboard',
    opts = { range = true },
  },
  {
    ':Cut',
    function(args)
      local line1, line2 = current_range(args)
      vim.cmd(string.format('silent %d,%dyank +', line1, line2))
      vim.cmd(string.format('silent %d,%ddelete _', line1, line2))
    end,
    description = 'Cut to clipboard',
    keywords = { 'cut', 'delete', 'clipboard' },
    category = 'Clipboard',
    opts = { range = true },
  },
  {
    ':Paste',
    function()
      vim.cmd('normal! "+p')
    end,
    description = 'Paste from clipboard',
    keywords = { 'paste', 'put', 'clipboard' },
    category = 'Clipboard',
  },
  {
    ':SelectAll',
    function()
      vim.cmd('normal! ggVG')
    end,
    description = 'Select all text',
    keywords = { 'select', 'all', 'buffer' },
    category = 'Select',
  },
  {
    ':DeleteLine',
    function()
      vim.cmd('delete _')
    end,
    description = 'Delete line',
    keywords = { 'delete', 'cut', 'line', 'remove' },
    category = 'Line',
  },
  {
    ':JoinLines',
    function(args)
      if args.range > 0 then
        vim.cmd(string.format('silent %d,%djoin', args.line1, args.line2))
      else
        vim.cmd('silent join')
      end
    end,
    description = 'Join lines',
    keywords = { 'join', 'line', 'merge' },
    category = 'Line',
    opts = { range = true },
  },
  {
    ':Uppercase',
    function(args)
      local line1, line2 = current_range(args)
      vim.cmd(string.format([[silent %d,%ds/.*/\U&/]], line1, line2))
      vim.cmd('nohlsearch')
    end,
    description = 'Convert to uppercase',
    keywords = { 'uppercase', 'upper', 'case' },
    category = 'Case',
    opts = { range = true },
  },
  {
    ':Lowercase',
    function(args)
      local line1, line2 = current_range(args)
      vim.cmd(string.format([[silent %d,%ds/.*/\L&/]], line1, line2))
      vim.cmd('nohlsearch')
    end,
    description = 'Convert to lowercase',
    keywords = { 'lowercase', 'lower', 'case' },
    category = 'Case',
    opts = { range = true },
  },
  {
    ':ToggleCase',
    function(args)
      local line1, line2 = current_range(args)
      vim.cmd(string.format('silent %d,%dnormal! g~~', line1, line2))
    end,
    description = 'Toggle case',
    keywords = { 'toggle', 'case', 'upper', 'lower' },
    category = 'Case',
    opts = { range = true },
  },
  {
    ':SortLines',
    function(args)
      local line1, line2 = current_range(args)
      vim.cmd(string.format('silent %d,%dsort', line1, line2))
    end,
    description = 'Sort lines ascending',
    keywords = { 'sort', 'lines', 'ascending' },
    category = 'Line',
    opts = { range = true },
  },
  {
    ':SortLinesReverse',
    function(args)
      local line1, line2 = current_range(args)
      vim.cmd(string.format('silent %d,%dsort!', line1, line2))
    end,
    description = 'Sort lines descending',
    keywords = { 'sort', 'lines', 'descending', 'reverse' },
    category = 'Line',
    opts = { range = true },
  },
  {
    ':TrimWhitespace',
    function()
      local view = vim.fn.winsaveview()
      vim.cmd([[keeppatterns %s/\s\+$//e]])
      vim.fn.winrestview(view)
    end,
    description = 'Trim trailing whitespace',
    keywords = { 'trim', 'whitespace', 'trailing', 'spaces' },
    category = 'Line',
  },
  {
    ':MoveLineDown',
    function(args)
      local count = (args.count and args.count > 0) and args.count or 1
      local line1, line2 = current_range(args)
      local dest = line2 + count
      vim.cmd(string.format('silent %d,%dmove %d', line1, line2, dest))
      vim.cmd(string.format('normal! %dG', line1 + count))
    end,
    description = 'Move line down',
    keywords = { 'move', 'line', 'down', 'selection' },
    category = 'Line',
    opts = { range = true },
  },
  {
    ':MoveLineUp',
    function(args)
      local count = (args.count and args.count > 0) and args.count or 1
      local line1, line2 = current_range(args)
      local dest = line1 - count - 1
      if dest < 0 then
        dest = 0
      end
      vim.cmd(string.format('silent %d,%dmove %d', line1, line2, dest))
      vim.cmd(string.format('normal! %dG', line1 - count))
    end,
    description = 'Move line up',
    keywords = { 'move', 'line', 'up', 'selection' },
    category = 'Line',
    opts = { range = true },
  },
  {
    ':DuplicateLineDown',
    function(args)
      local line1, line2 = current_range(args)
      vim.cmd(string.format('silent %d,%dt %d', line1, line2, line2))
    end,
    description = 'Duplicate line down',
    keywords = { 'duplicate', 'copy', 'line', 'down' },
    category = 'Line',
    opts = { range = true },
  },
  {
    ':DuplicateLineUp',
    function(args)
      local line1, line2 = current_range(args)
      local dest = line1 - 1
      if dest < 0 then
        dest = 0
      end
      vim.cmd(string.format('silent %d,%dt %d', line1, line2, dest))
    end,
    description = 'Duplicate line up',
    keywords = { 'duplicate', 'copy', 'line', 'up' },
    category = 'Line',
    opts = { range = true },
  },
  {
    ':ToggleFold',
    function()
      vim.cmd('normal! za')
    end,
    description = 'Toggle fold',
    keywords = { 'fold', 'toggle', 'collapse' },
    category = 'Fold',
  },
  {
    ':FoldAll',
    function()
      vim.cmd('normal! zM')
    end,
    description = 'Close all folds',
    keywords = { 'fold', 'close', 'all', 'collapse' },
    category = 'Fold',
  },
  {
    ':UnfoldAll',
    function()
      vim.cmd('normal! zR')
    end,
    description = 'Open all folds',
    keywords = { 'fold', 'open', 'all', 'unfold' },
    category = 'Fold',
  },
  {
    ':SplitHorizontal',
    function()
      vim.cmd('split')
    end,
    description = 'Split window horizontal',
    keywords = { 'window', 'split', 'horizontal' },
    category = 'Window',
  },
  {
    ':SplitVertical',
    function()
      vim.cmd('vsplit')
    end,
    description = 'Split window vertical',
    keywords = { 'window', 'split', 'vertical' },
    category = 'Window',
  },
  {
    ':CloseWindow',
    function()
      vim.cmd('close')
    end,
    description = 'Close window',
    keywords = { 'window', 'close', 'quit' },
    category = 'Window',
  },
  {
    ':CloseOtherWindows',
    function()
      vim.cmd('only')
    end,
    description = 'Close other windows',
    keywords = { 'window', 'close', 'only', 'others' },
    category = 'Window',
  },
  {
    ':NewTab',
    function()
      vim.cmd('tabnew')
    end,
    description = 'New tab page',
    keywords = { 'tab', 'new', 'open' },
    category = 'Tab',
  },
  {
    ':CloseTab',
    function()
      vim.cmd('tabclose')
    end,
    description = 'Close tab page',
    keywords = { 'tab', 'close' },
    category = 'Tab',
  },
  {
    ':SaveAll',
    function()
      vim.cmd('wall')
    end,
    description = 'Save all files',
    keywords = { 'save', 'write', 'all' },
    category = 'File',
  },
  {
    ':Format',
    function()
      local ok = pcall(vim.lsp.buf.format, { async = true })
      if not ok then
        vim.notify('No formatter available (LSP format failed)', vim.log.levels.WARN)
      end
    end,
    description = 'Format document',
    keywords = { 'format', 'document', 'lsp', 'prettier' },
    category = 'Format',
    opts = { range = true },
  },
  {
    ':ToggleComment',
    function()
      if is_visual() then
        vim.cmd('normal gc')
      else
        vim.cmd('normal gcc')
      end
    end,
    description = 'Toggle comment',
    keywords = { 'comment', 'toggle', 'line', 'selection' },
    category = 'Comment',
    opts = { range = true },
  },
}

return M
