local api = vim.api
local loop = vim.loop

local M = {}
local braille = {'⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠏'}

function M.start(bufnr, line)
  local ns = api.nvim_create_namespace("ai_spinner")
  local i = 1
  local timer = loop.new_timer()
  
  -- Initial mark
  local extmark_id = api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
      virt_text={{braille[i], "Comment"}},
      virt_text_pos="overlay"
  })

  timer:start(0, 100, vim.schedule_wrap(function()
    if not api.nvim_buf_is_valid(bufnr) then
      timer:stop()
      return
    end
    
    i = (i % #braille) + 1
    -- Update existing mark if possible
    pcall(api.nvim_buf_set_extmark, bufnr, ns, line, 0, {
        id = extmark_id,
        virt_text={{braille[i], "Comment"}},
        virt_text_pos="overlay"
    })
  end))

  return {
    stop = function()
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      if api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_clear_namespace(bufnr, ns, line, line + 1)
      end
    end
  }
end

return M
