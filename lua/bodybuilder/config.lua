local M = {}

M.defaults = {
  url = "http://localhost:11434/api/generate",
  model = "llama3", -- Change to your preferred model
  prompt_template = [[
You are an expert programmer. Your task is to implement the body of the function provided below.

Strict Instructions:
1. Return ONLY the code inside the function body.
2. Do NOT return the function signature.
3. Do NOT return the 'end' keyword.
4. Do NOT wrap the code in markdown code blocks (```).
5. Do NOT include any explanations or conversational text.

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