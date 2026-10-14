local class = require('legendary.vendor.middleclass')
local util = require('legendary.util')
local Filters = require('legendary.data.filters')

---@class Function
---@field implementation function
---@field description string
---@field keywords string[]
---@field category string|nil
---@field opts table
---@field filters (function[])|nil
---@field frecency_id fun(self):string
---@field class Function
local Function = class('Function')
Function:include(Filters) ---@diagnostic disable-line

function Function:parse(tbl) -- luacheck: no unused
  vim.validate({
    ['1'] = { tbl[1], { 'function' } },
    description = { util.get_desc(tbl), { 'string' } },
    keywords = { tbl.keywords, { 'string', 'table' }, true },
    category = { tbl.category, { 'string' }, true },
    opts = { tbl.opts, { 'table' }, true },
  })

  local instance = Function()

  instance.implementation = tbl[1]
  instance.description = util.get_desc(tbl)
  instance.keywords = util.get_keywords(tbl)
  instance.category = util.get_category(tbl)
  instance.opts = tbl.opts or {}
  instance:parse_filters(tbl.filters)

  return instance
end

function Function:apply() -- luacheck: no unused
  -- no-op, just for the sake of keeping the same interface
  -- between item types
  return self
end

function Function:id()
  return string.format(
    '<function> %s %s %s',
    self.description,
    table.concat(self.keywords or {}, ' '),
    vim.inspect(self.opts or {})
  )
end

function Function:frecency_id()
  return string.format('<function> %s %s', self.description, table.concat(self.keywords or {}, ' '))
end

---Return a searchable string combining description, category and keywords.
---@return string
function Function:search_text()
  local parts = { self.description }
  if self.category then
    table.insert(parts, self.category)
  end
  for _, kw in ipairs(self.keywords or {}) do
    table.insert(parts, kw)
  end
  return table.concat(parts, ' ')
end

return Function
