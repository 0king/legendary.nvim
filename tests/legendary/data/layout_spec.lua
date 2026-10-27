local assert = require('luassert')
local Layout = require('legendary.data.layout')
local Function = require('legendary.data.function')
local Keymap = require('legendary.data.keymap')

---@param description string
---@return table
local function find_action(description)
  for _, action in ipairs(Layout.actions) do
    if action.description == description then
      return action
    end
  end
  error('missing layout action: ' .. description)
end

describe('Layout catalogue', function()
  it('contains hand-written actions with searchable metadata', function()
    assert.is_true(#Layout.actions > 0)
    for _, action in ipairs(Layout.actions) do
      assert.are.same('function', type(action[1]))
      assert.are.same('string', type(action.description))
      assert.are.same('Layout', action.category)
      assert.are.same('table', type(action.keywords))
      assert.is_true(#action.keywords > 0)
      assert.are.same('layout', action.keywords[1])
    end
  end)

  it('contains hand-written keymaps with searchable metadata', function()
    assert.is_true(#Layout.keymaps > 0)
    for _, keymap in ipairs(Layout.keymaps) do
      assert.are.same('string', type(keymap[1]))
      assert.are.same('string', type(keymap.description))
      assert.are.same('Layout', keymap.category)
      assert.are.same('n', keymap.mode)
      assert.are.same('table', type(keymap.keywords))
      assert.is_true(#keymap.keywords > 0)
      assert.are.same('layout', keymap.keywords[1])
      assert.are.same('table', type(keymap.filters))
      assert.are.same('function', type(keymap.filters[1]))
    end
  end)

  it('parses actions as functions', function()
    for _, action in ipairs(Layout.actions) do
      local parsed = Function:parse(action)
      assert.are.same(action.description, parsed.description)
      assert.are.same('Layout', parsed.category)
    end
  end)

  it('parses keymaps as non-builtin description-only keymaps', function()
    for _, keymap in ipairs(Layout.keymaps) do
      local parsed = Keymap:parse(keymap)
      assert.is_false(parsed.builtin)
      assert.are.same('table', type(parsed.mode_mappings))
      assert.is_nil(parsed.mode_mappings.n)
    end
  end)

  it('hides keymaps whose binding does not exist', function()
    local parsed = Keymap:parse(Layout.keymaps[1])
    local filter = parsed.filters[1]

    assert.is_false(filter(parsed))

    vim.keymap.set('n', parsed.keys, '<cmd>tabnext<cr>', { desc = 'Layout catalogue test' })
    assert.is_true(filter(parsed))

    vim.keymap.del('n', parsed.keys)
    assert.is_false(filter(parsed))
  end)
end)

describe('Layout actions', function()
  it('focuses tab pages', function()
    local start_tab = vim.api.nvim_get_current_tabpage()
    local ok, err = pcall(function()
      vim.cmd('tabnew')
      vim.cmd('tabnew')

      assert.is_true(find_action('Focus first tab')[1]())
      assert.are.same(1, vim.fn.tabpagenr())

      assert.is_true(find_action('Focus next tab')[1]())
      assert.are.same(2, vim.fn.tabpagenr())

      assert.is_true(find_action('Focus last tab')[1]())
      assert.are.same(3, vim.fn.tabpagenr())

      assert.is_true(find_action('Focus previous tab')[1]())
      assert.are.same(2, vim.fn.tabpagenr())
    end)

    vim.api.nvim_set_current_tabpage(start_tab)
    vim.cmd('tabonly')

    if not ok then
      error(err)
    end
  end)

  it('focuses the editor window from a layout window', function()
    local start_tab = vim.api.nvim_get_current_tabpage()
    local ok, err = pcall(function()
      vim.cmd('tabnew')
      local editor = vim.api.nvim_get_current_win()
      vim.cmd('vsplit')
      local sidebar = vim.api.nvim_get_current_win()
      local sidebar_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(sidebar, sidebar_buf)
      vim.bo[sidebar_buf].filetype = 'NvimTree'
      vim.api.nvim_set_current_win(sidebar)

      assert.is_true(find_action('Focus editor')[1]())
      assert.are.same(editor, vim.api.nvim_get_current_win())
    end)

    vim.api.nvim_set_current_tabpage(start_tab)
    vim.cmd('tabonly')

    if not ok then
      error(err)
    end
  end)

  it('leaves focus in the editor when it is already there', function()
    local editor = vim.api.nvim_get_current_win()
    assert.is_true(find_action('Focus editor')[1]())
    assert.are.same(editor, vim.api.nvim_get_current_win())
  end)

  it('does not jump to picker.main when already in an editor window', function()
    local start_tab = vim.api.nvim_get_current_tabpage()
    local old_snacks = rawget(_G, 'Snacks')
    local old_loaded = package.loaded['snacks.picker']
    local old_preload = package.preload['snacks.picker']

    local ok, err = pcall(function()
      vim.cmd('tabnew')
      local other_editor = vim.api.nvim_get_current_win()
      vim.cmd('vsplit')
      local editor = vim.api.nvim_get_current_win()

      _G.Snacks = {}
      package.loaded['snacks.picker'] = nil
      package.preload['snacks.picker'] = function()
        return {
          get = function()
            return { { main = other_editor } }
          end,
        }
      end

      assert.is_true(find_action('Focus editor')[1]())
      assert.are.same(editor, vim.api.nvim_get_current_win())
    end)

    _G.Snacks = old_snacks
    package.loaded['snacks.picker'] = old_loaded
    package.preload['snacks.picker'] = old_preload

    vim.api.nvim_set_current_tabpage(start_tab)
    vim.cmd('tabonly')

    if not ok then
      error(err)
    end
  end)

  it('leaves a floating window when focusing the editor', function()
    local editor = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    local float = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      row = 1,
      col = 1,
      width = 10,
      height = 3,
    })

    local ok, err = pcall(function()
      assert.is_true(find_action('Focus editor')[1]())
      assert.are.same(editor, vim.api.nvim_get_current_win())
    end)

    pcall(vim.api.nvim_win_close, float, true)
    vim.api.nvim_set_current_win(editor)

    if not ok then
      error(err)
    end
  end)
end)
