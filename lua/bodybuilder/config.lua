local M = {}

M.defaults = {
  url = "http://localhost:11434/api/generate",
  model = "llama3", -- Change to your preferred model
  prompt_template = [[
Fill in ONLY the body of the function below. Do NOT rewrite the signature.
Respond only with valid code for the body. Do not wrap in markdown code blocks if possible, or I will have to strip them.

Signature:
%s

Docs:
%s

File context:
%s
]],
  stream = false, -- Ollama supports streaming
  keymap = nil -- Example: '<leader>af'
}

M.options = {}

function M.setup(options)
  M.options = vim.tbl_deep_extend("force", M.defaults, options or {})
end

return M
