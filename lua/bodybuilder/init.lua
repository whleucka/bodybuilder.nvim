local M = {}
local config = require('bodybuilder.config')
local ts = require('bodybuilder.treesitter')
local spinner = require('bodybuilder.spinner')
local curl = require('plenary.curl')

-- Helper to strip markdown code blocks and repeated signatures
local function clean_response(text, signature)
  -- 1. Try to find markdown code block
  local code_content = text:match("```%w*\n(.-)\n```")
  if code_content then
    text = code_content
  else
    -- Fallback: strip leading/trailing backticks
    text = text:gsub("^%s*```%w*%s*", ""):gsub("%s*```%s*$", "")
  end

  local lines = vim.split(text, "\n")
  
  -- 2. Strip empty lines at start/end
  while #lines > 0 and lines[1]:match("^%s*$") do table.remove(lines, 1) end
  while #lines > 0 and lines[#lines]:match("^%s*$") do table.remove(lines, #lines) end

  local function normalize(s) return s:gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "") end

  -- 2b. Strip PHP opening/closing tags if present on their own lines
  if #lines > 0 and normalize(lines[1]) == "<?php" then
    table.remove(lines, 1)
  end
  if #lines > 0 and normalize(lines[#lines]) == "?>" then
    table.remove(lines, #lines)
  end
  -- Re-check empty lines after PHP tag removal
  while #lines > 0 and lines[1]:match("^%s*$") do table.remove(lines, 1) end
  while #lines > 0 and lines[#lines]:match("^%s*$") do table.remove(lines, #lines) end

  -- 3. Heuristic: Strip duplicated signature if present
  -- Search first few lines (e.g. 5) for the signature
  if signature and #lines > 0 then
    local sig_norm = normalize(signature)
    local found_idx = nil
    
    for i = 1, math.min(#lines, 5) do
      local line_norm = normalize(lines[i])
      if line_norm == sig_norm or line_norm:find(sig_norm, 1, true) then
        found_idx = i
        break
      end
    end
    
    if found_idx then
      -- Remove everything up to and including the signature
      for _ = 1, found_idx do
        table.remove(lines, 1)
      end
      
      -- If we stripped the signature, check if the last line is a closing brace/end for that wrapper
      -- We'll assume the last line is the wrapper closer if it's just '}' or 'end'
      if #lines > 0 then
         local last_norm = normalize(lines[#lines])
         if last_norm == "}" or last_norm == "end" then
            table.remove(lines, #lines)
         end
      end
    end
  end

  -- 4. Strip surrounding braces { } if they appear to wrap the whole body
  -- (Common in C-style languages where model returns { ... })
  -- NOTE: If step 3 ran, it might have already stripped the wrapper braces if the signature was present.
  -- This step catches cases where the model returns "{ ... }" WITHOUT the signature.
  if #lines >= 2 then
    local first = normalize(lines[1])
    local last = normalize(lines[#lines])
    if first == "{" and last == "}" then
      table.remove(lines, 1)
      table.remove(lines, #lines)
    end
  elseif #lines == 1 then
    -- Single line case: "{ return 1; }" -> "return 1;"
    local l = lines[1]
    local s, e = l:find("^{.*}$")
    if s then
       -- extraction logic is tricky for single line, let's keep it simple for now
       -- assuming multi-line response for complex bodies
    end
  end

  -- Re-strip empty lines after brace removal
  while #lines > 0 and lines[1]:match("^%s*$") do table.remove(lines, 1) end
  while #lines > 0 and lines[#lines]:match("^%s*$") do table.remove(lines, #lines) end

  return lines
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

  local f_start_row, _, _, _ = node:range()
  local start_row, end_row
  local body_node = ts.get_body_node(node)
  
  if body_node then
    start_row, _, end_row, _ = body_node:range()
  else
    -- Fallback
    start_row, _, end_row, _ = node:range()
  end

  -- Check if there is actually space (multi-line required)
  if end_row <= start_row then
    vim.notify("Function seems too short to have a body.", vim.log.levels.WARN)
    return
  end

  -- Prepare context
  -- Signature from function start
  local signature = vim.api.nvim_buf_get_lines(bufnr, f_start_row, f_start_row+1, false)[1]
  local docs = ts.get_docstring(node)
  local file_context = ts.get_context(bufnr, node)
  
  local filetype = vim.bo[bufnr].filetype or "unknown"

  local prompt = string.format(config.options.prompt_template, filetype, signature, docs, file_context)

  -- Indentation helpers
  local function get_indent(line_idx)
    local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx+1, false)[1] or ""
    return line:match("^(%s*)") or ""
  end
  
  local shift_width = vim.bo[bufnr].shiftwidth
  local expand_tab = vim.bo[bufnr].expandtab
  local indent_char = expand_tab and string.rep(" ", shift_width) or "\t"
  
  -- Range to replace calculation
  local replace_start, replace_end, base_indent_str
  
  -- Python and Lua usually have bodies that are "blocks" without wrapping braces in the same way C/JS do
  -- (Lua 'end' is part of the parent function node usually, or we treat the inner block differently)
  -- For Python, the body node IS the content.
  if filetype == "python" or filetype == "lua" then
    replace_start = start_row
    replace_end = end_row + 1 -- end_row is inclusive, set_lines end is exclusive
    
    -- Base indent is the function definition's indent
    base_indent_str = get_indent(f_start_row)
  else
    -- Default to C-style braced blocks { ... }
    -- We want to keep the braces at start_row and end_row
    replace_start = start_row + 1
    replace_end = end_row
    
    -- Base indent from the closing brace
    base_indent_str = get_indent(end_row)
  end

  local target_indent = base_indent_str .. indent_char
  
  -- UI: Clear body and show spinner
  -- We clear the content between braces
  vim.api.nvim_buf_set_lines(bufnr, replace_start, replace_end, false, { "" }) 
  
  local spinner_line = replace_start
  -- Insert a placeholder line for the spinner to attach to
  -- Note: set_lines with same start/end inserts.
  -- But we just replaced the range with {""}. So line replace_start IS empty.
  -- We don't need to insert another one.
  -- Wait: set_lines(..., replace_start, replace_end, ..., {""})
  -- If replace_start < replace_end (we had content), it is replaced by empty line.
  -- If replace_start == replace_end (empty body), it inserts empty line.
  -- In both cases, line replace_start exists and is empty.
  
  local spin_handle = spinner.start(bufnr, spinner_line)

  -- Async request
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
    timeout = config.options.timeout,
    callback = vim.schedule_wrap(function(response)
      spin_handle.stop()      
      if response.status ~= 200 then
        vim.notify("AI Request Failed: " .. (response.body or "Unknown error"), vim.log.levels.ERROR)
        vim.api.nvim_buf_set_lines(bufnr, spinner_line, spinner_line+1, false, { target_indent .. "Failed 😢" })
        return
      end

      local data = vim.fn.json_decode(response.body)
      local result_text = ""
      
      if data.response then
        result_text = data.response
      elseif data.choices and data.choices[1] then
        local choice = data.choices[1]
        if choice.message and choice.message.content then
          result_text = choice.message.content
        elseif choice.text then
          result_text = choice.text
        end
      end
      
      local lines = clean_response(result_text, signature)
      
      -- Dedent lines (remove common prefix whitespace from AI response)
      local common_indent = nil
      for _, line in ipairs(lines) do
        if #line > 0 then
          local indent = line:match("^(%s*)")
          if common_indent == nil or #indent < #common_indent then
            common_indent = indent
          end
        end
      end
      
      if common_indent and #common_indent > 0 then
        for i, line in ipairs(lines) do
          lines[i] = line:sub(#common_indent + 1)
        end
      end

      -- Re-indent with target_indent
      for i, line in ipairs(lines) do
        if #line > 0 then
           lines[i] = target_indent .. line
        end
      end
      
      -- Ensure buffer is still valid and we are within range
      if vim.api.nvim_buf_is_valid(bufnr) then
          local current_lines = vim.api.nvim_buf_line_count(bufnr)
          if spinner_line < current_lines then
              -- Replace the placeholder line with the generated lines
              vim.api.nvim_buf_set_lines(bufnr, spinner_line, spinner_line+1, false, lines)
          end
      end
    end)
  })
end

return M
