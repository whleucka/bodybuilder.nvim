local ts_utils = require('nvim-treesitter.ts_utils')
local vim = vim

local M = {}

-- simple check for function type nodes
local function is_function_node(node)
  local type = node:type()
  return type:match('function_definition') 
      or type:match('method_definition') 
      or type:match('function_declaration')
      or type:match('method_declaration')
      or type == 'function_item' -- Rust
end

function M.get_current_function_node()
  local node = ts_utils.get_node_at_cursor()
  while node do
    if is_function_node(node) then
      return node
    end
    node = node:parent()
  end
  return nil
end

function M.get_body_node(node)
  -- Try to find child by field name 'body'
  if node.child_by_field_name then
    local body = node:child_by_field_name("body")
    if body then return body end
  end
  
  -- Fallback: iterate children and look for block-like types
  for child in node:iter_children() do
    local type = child:type()
    if type == "block" or type == "compound_statement" or type == "statement_block" then
      return child
    end
  end
  return nil
end

function M.get_function_text(node)
  return ts_utils.get_node_text(node)
end

-- Attempt to get docstrings (comments immediately preceding the node)
function M.get_docstring(node)
  local prev = node:prev_sibling()
  local comments = {}
  while prev do
    local type = prev:type()
    if type == 'comment' then
      local text = ts_utils.get_node_text(prev)
      if text then
        table.insert(comments, 1, table.concat(text, "\n"))
      end
    elseif type:match("^%s*$") then
      -- Skip pure whitespace nodes if they exist as nodes (rare in high level API but possible)
    else
      -- Stop if we hit something that isn't a comment
      break
    end
    prev = prev:prev_sibling()
  end
  return table.concat(comments, "\n")
end

-- Get some surrounding context (naive: N lines before and after)
function M.get_context(bufnr, node, context_lines)
  context_lines = context_lines or 20
  local start_row, _, end_row, _ = node:range()
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  
  local context_start = math.max(0, start_row - context_lines)
  local context_end = math.min(total_lines, end_row + context_lines)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, context_start, context_end, false)
  return table.concat(lines, "\n")
end

return M
