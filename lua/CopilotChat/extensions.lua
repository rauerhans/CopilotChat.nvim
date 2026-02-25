local chat = require("CopilotChat")
local config = require("CopilotChat.config")
local extendedprompts = require("CopilotChat.config.extendedprompts")

local M = {}


local function new_chat_window(prompt, opts)
  vim.g.copilot_chat_title = nil -- Reset chat title used for saving chat history
  chat.reset()

  if prompt ~= "" then
    chat.ask(prompt, opts)
  else
    -- this is where we use the original
    chat.open(opts)
    if opts.load then
      chat.load(opts.load)
    end
  end
end

local function get_model_for_operation(operation_type)
  -- Define model environment variables in a central configuration
  local MODEL_ENV_VARS = {
    reason = "COPILOT_MODEL_REASON",   -- Used for analysis operations
    codegen = "COPILOT_MODEL_CODEGEN", -- Default for code generation
  }

  -- Use a Set for faster lookups of analysis operations
  local ANALYSIS_OPERATIONS = {
    architect = true,
    explain = true,
    review = true,
    -- Have refactor here to act as second opinion to codegen
    refactor = true,
  }

  -- Determine appropriate model type with fallbacks
  local env_var = MODEL_ENV_VARS.codegen
  if ANALYSIS_OPERATIONS[operation_type] then
    env_var = MODEL_ENV_VARS.reason
  end

  -- Retrieve model with safety checks
  local selected_model = T.env.get(env_var)
  if not selected_model or selected_model == vim.NIL then
    local msg =
        string.format("Warning: Environment variable %s not set for operation '%s'", env_var, operation_type)
    vim.notify(msg, vim.log.levels.WARN)
    return nil -- Could add default fallback here
  end

  return selected_model
end

local function get_visual_selection()
  -- Yank the visual selection
  vim.cmd('normal! "zy')
  local selection = vim.fn.getreg("z")
  -- Remove leading non-alphanumeric characters
  selection = vim.trim(selection:gsub("^[^a-zA-Z0-9]+", ""))

  return selection
end



function M.open_chat(type)
  return function()
    local sticky = {}

    local model = get_model_for_operation(type)
    local system_prompt = extendedprompts.get_system_prompt(type)

    if type == "assistance" then
      local is_visual_mode = vim.fn.mode():match("[vV]") ~= nil
      sticky = extendedprompts.get_sticky_prompts()
      if is_visual_mode then
        table.insert(sticky, #sticky + 1, "#selection")
      else
        table.insert(sticky, #sticky + 1, "#buffer")
      end
    elseif type == "architect" then
    elseif type == "search" then
    end

    new_chat_window("", {
      model = model,
      sticky = sticky,
      system_prompt = system_prompt,
    })
  end
end

function M.action(type, opts)
  return function()
    local prompt = "Please"

    local sticky = extendedprompts.get_sticky_prompts()
    table.insert(sticky, "/" .. type)

    local is_visual_mode = vim.fn.mode():match("[vV]") ~= nil

    if type == "generic" then
    elseif type == "implement" then
      prompt = get_visual_selection() .. "\n\n"
      table.insert(sticky, #sticky + 1, "#buffer")
    elseif type == "fix" then
      local scope = is_visual_mode and "selection" or "current"
      if scope == "selection" then
        table.insert(sticky, #sticky + 1, "#selection")
      elseif scope == "current" then
        table.insert(sticky, #sticky + 1, "#buffer")
      end
      table.insert(sticky, #sticky + 1, "#diagnostics:" .. scope)
    elseif is_visual_mode then
      table.insert(sticky, #sticky + 1, "#selection")
    else
      table.insert(sticky, #sticky + 1, "#buffer")
    end

    new_chat_window(prompt, {
      model = get_model_for_operation(type),
      system_prompt = extendedprompts.get_system_prompt(type),
      sticky = sticky,
      inline = opts and opts.inline or false,
    })
  end
end

function M.delete_old_chat_files()
  local scandir = require("plenary.scandir")

  local files = scandir.scan_dir(config.history_path, {
    search_pattern = "%.json$",
    depth = 1,
  })

  local current_time = os.time()
  local one_month_ago = current_time - (30 * 24 * 60 * 60) -- 30 days in seconds
  local deleted_count = 0

  for _, file in ipairs(files) do
    local mtime = vim.fn.getftime(file)

    if mtime < one_month_ago then
      local success, err = os.remove(file)
      if success then
        deleted_count = deleted_count + 1
      else
        vim.notify("Failed to delete old chat file: " .. err, vim.log.levels.WARN)
      end
    end
  end

  if deleted_count > 0 then
    vim.notify("Deleted " .. deleted_count .. " old chat files", vim.log.levels.INFO)
  end
end

function M.generate_commit_message()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Determine which prompt command to use based on work environment
  local is_work_env = T.env.get_bool("IS_WORK")
  local prompt = "/" .. (is_work_env and "commitwork" or "commit")

  chat.reset() -- Reset previous chat state

  T.fn.start_spinner(bufnr, "Generating commit message...")

  chat.ask(prompt, {
    callback = function(response)
      T.fn.stop_spinner(bufnr)

      -- Convert response to table of lines and ensure it's always an array
      local lines = type(response) == "string" and vim.split(response, "\n")
          or (type(response) == "table" and response or {})
      table.insert(lines, "")

      -- Insert the response at cursor position
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Set cursor on the last line
      vim.cmd("normal! G")
      return response
    end,
    headless = true,
    model = T.env.get("COPILOT_MODEL_CHEAP"),
    sticky = { "#gitdiff:staged" },
    system_prompt = "/COPILOT_INSTRUCTIONS",
  })
end

return M
