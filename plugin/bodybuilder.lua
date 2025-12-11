if vim.g.loaded_bodybuilder then
  return
end
vim.g.loaded_bodybuilder = 1

local bodybuilder = require("bodybuilder.init")
local config = require("bodybuilder.config")

-- Setup command
vim.api.nvim_create_user_command("AIFillBody", function()
  bodybuilder.fill_method_body()
end, {})

-- Expose setup function globally via the module
-- Users will require("bodybuilder").setup({...}) in their init.lua
-- But we can also expose a global if needed, but module require is standard.

-- Optional: Default keymap if user wants it, but usually we leave it to them.
-- Usage: vim.keymap.set('n', '<leader>af', ':AIFillBody<CR>', { noremap = true, silent = true })
