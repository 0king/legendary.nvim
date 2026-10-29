local assert = require('luassert')
local Config = require('legendary.config')
local Format = require('legendary.ui.format')
local Keymap = require('legendary.data.keymap')

describe('default_format', function()
  it('prefixes the mode column with the catalogue marker', function()
    local item = Keymap:parse({ '<leader>f', description = 'test', marker = '👉' })
    local cols = Format.default_format(item)
    assert.are.same('👉 n', cols[1])
    assert.are.same('<leader>f', cols[2])
    assert.are.same('test', cols[3])
  end)

  it('leaves keymaps without a marker unchanged', function()
    local item = Keymap:parse({ '<leader>f', description = 'test' })
    assert.are.same('n', Format.default_format(item)[1])
  end)

  it('keeps a custom keymap icon after the marker', function()
    local previous = Config.icons.keymap
    Config.icons.keymap = 'K'

    local ok, err = pcall(function()
      local item = Keymap:parse({ '<leader>f', description = 'test', marker = '🏡' })
      assert.are.same('🏡 K', Format.default_format(item)[1])
    end)

    Config.icons.keymap = previous
    if not ok then
      error(err)
    end
  end)
end)
