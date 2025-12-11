# bodybuilder-nvim 💪

Pump up your functions! Automatically fill in the body of your methods/functions with AI, keeping your signatures and docs intact. Designed for Neovim, fully async, and with a neat virtual-text spinner while generating.

## Features

- **Treesitter Powered**: Smartly extracts function signature, docstrings, and context.
- **Async & Non-blocking**: Uses `plenary.curl` to fetch completions without freezing the editor.
- **Visual Feedback**: Shows a Braille spinner (`⠋⠙⠹...`) inside the function body while generating.
- **AI Backend Agnostic**: Works with any OpenAI-compatible API (Ollama, LocalAI, etc.).

## Installation

### Dependencies

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Lazy.nvim

```lua
{
  "username/bodybuilder-nvim",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("bodybuilder").setup({
      -- Optional configuration
      url = "http://localhost:11434/api/generate",
      model = "llama3",
      keymap = "<leader>af",
    })
  end
}
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
})
```

## Contributing

PRs welcome!