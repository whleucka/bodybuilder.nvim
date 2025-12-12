# bodybuilder.nvim

**WARNING** this is a work in progress, so use it at your own risk.

Pump up your code! Automatically generate the body of your functions or methods using AI, keeping your signatures and docstrings intact. Built for Neovim and fully async, so your workflow never skips a beat.

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
  keymap = "<leader>ab",
})
```

## Usage

1.  Move cursor to any line inside a function definition.
2.  Press `<leader>ab` (or your configured keymap).
3.  Wait for the spinner to finish.
4.  The body will be replaced with the AI generated code.

## Configuration

Default options:

```lua
require("bodybuilder").setup({
  url = "http://localhost:11434/api/generate", -- Endpoint (Ollama default)
  model = "llama3",
  prompt_template = "...", -- See config.lua for default
  keymap = nil, -- Set to string (e.g. '<leader>ab') to auto-register
  timeout = 10000, -- Timeout in milliseconds (default: 10000)
})
```

## Contributing

PRs welcome!
