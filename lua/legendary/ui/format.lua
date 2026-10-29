---@mod legendary.ui.format

local Config = require('legendary.config')
local Toolbox = require('legendary.toolbox')

local M = {}

local function rpad(str, len)
  return string.format('%s%s', str, string.rep(' ', len - (vim.fn.strdisplaywidth(str))))
end

---@alias LegendaryItemFormatter fun(items:LegendaryItem[],mode:string):string[]

---Build the searchable display text for an item, combining description,
---category and keywords so any `vim.ui.select()` handler fuzzy-matches
---on human concepts (e.g. "copy", "fold all") and not just keys/cmd names.
---@param item LegendaryItem
---@return string
function M.search_text(item)
  if type(item.search_text) == 'function' then
    local ok, text = pcall(function()
      return item:search_text()
    end)
    if ok and type(text) == 'string' and #text > 0 then
      return text
    end
  end
  return item.description or ''
end

---Decorate a description with `[category]` badge and keywords.
---Keywords are embedded (not just appended invisibly) so every picker
---matches them.
---@param item LegendaryItem
---@return string
local function display_desc(item)
  local desc = item.description or ''
  local suffix_parts = {}
  if item.category and #item.category > 0 then
    table.insert(suffix_parts, string.format('[%s]', item.category))
  end
  local keywords = item.keywords or {}
  if #keywords > 0 then
    table.insert(suffix_parts, string.format('(%s)', table.concat(keywords, ', ')))
  end
  if #suffix_parts == 0 then
    return desc
  end
  if #desc == 0 then
    return table.concat(suffix_parts, ' ')
  end
  return string.format('%s %s', desc, table.concat(suffix_parts, ' '))
end

---Default format
---@param item LegendaryItem
---@return string[]
function M.default_format(item)
  if Toolbox.is_keymap(item) then
    local type_col = Config.icons.keymap or table.concat(item--[[@as Keymap]]:modes(), ', ')
    if item.marker and #item.marker > 0 then
      type_col = string.format('%s %s', item.marker, type_col)
    end
    return {
      type_col,
      item.keys,
      display_desc(item),
    }
  elseif Toolbox.is_command(item) then
    return {
      Config.icons.command,
      item.cmd,
      display_desc(item),
    }
  elseif Toolbox.is_autocmd(item) then
    local pattern = vim.tbl_get(item, 'opts', 'pattern') or { '*' }
    if type(pattern) == 'string' then
      pattern = { pattern }
    end
    return {
      table.concat(item.events, ', '),
      table.concat(pattern, ', '),
      display_desc(item),
    }
  elseif Toolbox.is_function(item) then
    return {
      Config.icons.fn,
      '<function>',
      display_desc(item),
    }
  elseif Toolbox.is_itemgroup(item) then
    return {
      item.icon or Config.icons.itemgroup,
      item.name,
      item.description or 'Expand to select an item...',
    }
  else
    -- unreachable
    return {
      vim.inspect(item),
      '',
      '',
    }
  end
end

---Format items
---@param items LegendaryItem[]
---@param mode string
---@param formatter LegendaryItemFormatter
function M.compute_padding(items, formatter, mode)
  formatter = formatter or M.default_format
  local format_values = vim.tbl_map(function(item)
    return formatter(item, mode)
  end, items)

  local padding = {}
  for _, cols in ipairs(format_values) do
    for i, col in ipairs(cols) do
      padding[i] = padding[i] or 0
      local len = vim.fn.strdisplaywidth(col)
      if len > padding[i] then
        padding[i] = len
      end
    end
  end

  return padding
end

---Format a single item, meant to be used in `vim.ui.select()`
---@param item LegendaryItem
---@param formatter LegendaryItemFormatter
---@param padding integer[]
---@param mode string
---@return string
function M.format_item(item, formatter, padding, mode)
  formatter = formatter or M.default_format
  local values = formatter(item, mode)
  local cols = {}
  for i, col in ipairs(values) do
    table.insert(cols, rpad(col, padding[i] or 0))
  end

  local format_str =
    string.format('%%s%s', string.rep(string.format(' %s %%s', Config.col_separator_char), #values - 1))
  return string.format(format_str, unpack(cols))
end

return M
