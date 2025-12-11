local M = {}
local config = require('bodybuilder.config')
local ts = require('bodybuilder.treesitter')
local spinner = require('bodybuilder.spinner')
local curl = require('plenary.curl')

-- Helper to strip markdown code blocks
local function clean_response(text)
  -- Try to find markdown code block
  local code_content = text:match("```%w*\n(.-)\n```")
  if code_content then
    text = code_content
  else
    -- Fallback: strip leading/trailing backticks if they exist without newline structure
    text = text:gsub("^%s*```%w*%s*", ""):gsub("%s*```%s*$", "")
  end
  -- Split into lines
  return vim.split(text, "\n")
end

function M.setup(options)
  config.setup(options)
  if config.options.keymap then
    vim.keymap.set('n', config.options.keymap, '<cmd>AIFillBody<CR>', { noremap = true, silent = true, desc = "AI Fill Method Body" })
  end
end

function M.fill_method_body()
  local bufnr = vim.api.nvim_get_current_buf()
  local node = ts.get_current_function_node()
  
  if not node then
    vim.notify("No function definition found at cursor.", vim.log.levels.WARN)
    return
  end

  local start_row, _, end_row, _ = node:range()
  -- Assume body is between start_row and end_row.
  -- We want to preserve the signature (start_row) and the closing token (end_row usually).
  -- This is a heuristic. For robust body detection, we'd need per-language queries.
  -- But replacing from start_row+1 to end_row-1 is a safe bet for "body content".
  
  -- Check if there is actually space
  if end_row <= start_row then
    -- One line function?
    vim.notify("Function seems too short to have a body.", vim.log.levels.WARN)
    return
  end

  -- Prepare context
  local signature = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row+1, false)[1]
  local docs = ts.get_docstring(node)
  local file_context = ts.get_context(bufnr, node)

  local prompt = string.format(config.options.prompt_template, signature, docs, file_context)

  -- UI: Clear body and show spinner
  -- Delete existing body lines
  vim.api.nvim_buf_set_lines(bufnr, start_row + 1, end_row, false, { "" }) 
  -- Now we have a blank line at start_row + 1. 
  -- Note: end_row was the index of the last line. 
  -- set_lines(buffer, start, end, strict, replacement)
  -- If we replace range (start_row+1, end_row) with {""}, we effectively clear it.
  -- But we need to make sure we don't delete the `end` keyword line if `end_row` points to it.
  -- Treesitter range is 0-indexed, [start_row, end_row). wait.
  -- `node:range()` returns 0-indexed start_row, start_col, end_row, end_col.
  -- In API, end_row is exclusive. 
  -- So if a function is lines 10 to 12 (3 lines). Range might be 10, 0, 12, 3.
  -- Lines are 10, 11, 12.
  -- Body is line 11.
  -- We want to replace line 11.
  -- API: set_lines(buf, 10+1, 12, ...) -> replaces 11... wait.
  -- 10 is signature. 12 is `end`.
  -- We want to replace from 11 to 12 (exclusive). So just line 11.
  -- Yes, start_row + 1, end_row.

  local spinner_line = start_row + 1
  -- Insert a placeholder comment for the spinner to attach to
  vim.api.nvim_buf_set_lines(bufnr, spinner_line, spinner_line+1, false, { "-- generating..." })
  
  local spin_handle = spinner.start(bufnr, spinner_line)

  -- Async request
  -- We use curl.post
  local url = config.options.url
  local payload = {
    model = config.options.model,
    prompt = prompt,
    stream = false
  }

  curl.post(url, {
    body = vim.fn.json_encode(payload),
    headers = {
      ["Content-Type"] = "application/json",
    },
    callback = vim.schedule_wrap(function(response)
      spin_handle.stop()      
      if response.status ~= 200 then
        vim.notify("AI Request Failed: " .. (response.body or "Unknown error"), vim.log.levels.ERROR)
        -- Restore placeholder or leave it as error indication?
        vim.api.nvim_buf_set_lines(bufnr, spinner_line, spinner_line+1, false, { "-- Generation failed." })
        return
      end

      local data = vim.fn.json_decode(response.body)
      local result_text = ""
      
      if data.response then
        -- Ollama /api/generate
        result_text = data.response
      elseif data.choices and data.choices[1] then
        -- OpenAI style
        local choice = data.choices[1]
        if choice.message and choice.message.content then
          result_text = choice.message.content
        elseif choice.text then
          result_text = choice.text
        end
      end
      
      local lines = clean_response(result_text)
      
      -- Replace the placeholder line with the generated lines
      -- The placeholder is at spinner_line (single line).
      -- We replace [spinner_line, spinner_line+1) with new lines.
      vim.api.nvim_buf_set_lines(bufnr, spinner_line, spinner_line+1, false, lines)
    end)
  })
end

return M
