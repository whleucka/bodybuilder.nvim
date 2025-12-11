# bodybuilder-nvim 💪

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/163f207b-955c-4ca3-8b10-544dce2d0388" />

**NOTE** this is a work in progress, so use it at your own risk.

Pump up your functions! Automatically fill in the body of your methods/functions with AI, keeping your signatures and docs intact. Designed for Neovim, fully async, and with a virtual-text spinner that’s more persistent than your gym buddy during leg day.

## Features

- **Treesitter Powered**: Smartly extracts function signature, docstrings, and context.
- **Async & Non-blocking**: Uses `plenary.curl` to fetch completions without freezing the editor.
- **AI Backend Agnostic**: Works with any OpenAI-compatible API (Ollama, LocalAI, etc.).

## Installation

### Dependencies

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### vim.pack

```lua
vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/whleucka/bodybuilder-nvim"
})

require("bodybuilder").setup({
  model = "gemma3:270m",  -- Matches the NAME from your ollama list
  keymap = "<leader>af",
})
```

## Usage

1.  Move cursor to any line inside a function definition.
2.  Press `<leader>af` (or your configured keymap).
3.  Wait for the spinner to finish.
4.  The body will be replaced with the AI generated code.

## Configuration

Default options:

```lua
require("bodybuilder").setup({
  url = "http://localhost:11434/api/generate", -- Endpoint (Ollama default)
  model = "llama3",
  prompt_template = "...", -- See config.lua for default
  keymap = nil, -- Set to string (e.g. '<leader>af') to auto-register
  timeout = 10000, -- Timeout in milliseconds (default: 10000)
})
```

## Contributing

PRs welcome!
