local assert = require('luassert')
local Explorer = require('legendary.data.explorer')
local Function = require('legendary.data.function')
local Keymap = require('legendary.data.keymap')

describe('Explorer catalogue', function()
  it('contains hand-written actions with searchable metadata', function()
    assert.is_true(#Explorer.actions > 0)
    for _, action in ipairs(Explorer.actions) do
      assert.are.same('function', type(action[1]))
      assert.are.same('string', type(action.description))
      assert.are.same('Explorer', action.category)
      assert.are.same('table', type(action.keywords))
      assert.is_true(#action.keywords > 0)
      assert.are.same('explorer', action.keywords[1])
    end
  end)

  it('contains hand-written keymaps with searchable metadata', function()
    assert.is_true(#Explorer.keymaps > 0)
    for _, keymap in ipairs(Explorer.keymaps) do
      assert.are.same('string', type(keymap[1]))
      assert.are.same('string', type(keymap.description))
      assert.are.same('Explorer', keymap.category)
      assert.are.same('table', type(keymap.keywords))
      assert.is_true(#keymap.keywords > 0)
      assert.are.same('explorer', keymap.keywords[1])
      assert.are.same('table', type(keymap.filters))
      assert.are.same('function', type(keymap.filters[1]))
    end
  end)

  it('parses actions as functions', function()
    for _, action in ipairs(Explorer.actions) do
      local parsed = Function:parse(action)
      assert.are.same(action.description, parsed.description)
      assert.are.same('Explorer', parsed.category)
    end
  end)

  it('parses keymaps as non-builtin description-only keymaps', function()
    for _, keymap in ipairs(Explorer.keymaps) do
      local parsed = Keymap:parse(keymap)
      assert.is_false(parsed.builtin)
      assert.are.same('table', type(parsed.mode_mappings))
      assert.is_nil(parsed.mode_mappings.n)
    end
  end)

  it('does not use <leader> in keymaps', function()
    for _, keymap in ipairs(Explorer.keymaps) do
      assert.is_nil(keymap[1]:find('<leader>', 1, true))
    end
  end)

  local function with_fake_explorer(fn)
    local old_snacks = rawget(_G, 'Snacks')
    local old_loaded = package.loaded['snacks.picker']
    local old_preload = package.preload['snacks.picker']
    _G.Snacks = {}
    package.loaded['snacks.picker'] = nil
    package.preload['snacks.picker'] = function()
      return {
        get = function()
          return { { list = { win = { buf = 42 } }, input = { win = { buf = 41 } }, preview = { win = { buf = 40 } } } }
        end,
      }
    end

    local ok, err = pcall(fn)

    _G.Snacks = old_snacks
    package.loaded['snacks.picker'] = old_loaded
    package.preload['snacks.picker'] = old_preload

    if not ok then
      error(err)
    end
  end

  it('filters keymaps to the snacks explorer list buffer', function()
    local filter = Explorer.keymaps[1].filters[1]
    assert.is_false(filter(nil, { buf = 0, filetype = 'lua' }))

    with_fake_explorer(function()
      assert.is_true(filter(nil, { buf = 42, filetype = 'snacks_picker_list' }))
      assert.is_false(filter(nil, { buf = 43, filetype = 'snacks_picker_list' }))
    end)
  end)

  it('filters selection actions to sessions with an open snacks explorer', function()
    local action
    for _, candidate in ipairs(Explorer.actions) do
      if candidate.description == 'Refresh explorer' then
        action = candidate
        break
      end
    end
    assert.is_true(action ~= nil)
    local filter = action.filters[1]
    assert.is_false(filter(nil, { buf = 0, filetype = 'lua' }))
    assert.is_true(filter(nil, { buf = 0, filetype = 'NvimTree' }))

    with_fake_explorer(function()
      assert.is_true(filter(nil, { buf = 42, filetype = 'snacks_picker_list' }))
      assert.is_true(filter(nil, { buf = 41, filetype = 'snacks_picker_input' }))
      assert.is_true(filter(nil, { buf = 40, filetype = 'lua' }))
      -- The palette may be opened from any buffer while the explorer is open.
      assert.is_true(filter(nil, { buf = 43, filetype = 'lua' }))
    end)
  end)
end)
