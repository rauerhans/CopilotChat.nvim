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

function M.customize_chat_window()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    pattern = "copilot-chat",
    callback = function()
      vim.opt_local.conceallevel = 0
      vim.opt_local.signcolumn = "yes:1"
      vim.opt_local.foldlevel = 999
      vim.opt_local.foldlevelstart = 99
      vim.opt_local.formatoptions:remove("r")
      vim.api.nvim_win_set_var(0, "side_panel", true)
    end,
  })
end

function M.decode_title(encoded_title)
  -- Extract the timestamp part (before first underscore)
  local timestamp, encoded = encoded_title:match("^(%d%d%d%d%d%d%d%d_%d%d%d%d%d%d)_(.+)$")

  -- Restore base64 padding characters
  local padding_len = 4 - (#encoded % 4)
  if padding_len < 4 then
    encoded = encoded .. string.rep("=", padding_len)
  end

  -- Restore original base64 characters
  encoded = encoded:gsub("_", "/"):gsub("-", "+")

  -- Decode and return with timestamp if successful
  local success, decoded = pcall(vim.base64.decode, encoded)
  if success and timestamp then
    return timestamp .. ": " .. decoded
  else
    return encoded_title -- Fallback to encoded if decoding fails
  end
end

function M.list_chat_history()
  local snacks = require("snacks")
  local chat = require("CopilotChat")
  local scandir = require("plenary.scandir")

  -- Delete old chat files first
  M.delete_old_chat_files()

  local files = scandir.scan_dir(CHAT_HISTORY_DIR, {
    search_pattern = "%.json$",
    depth = 1,
  })

  if #files == 0 then
    vim.notify("No chat history found", vim.log.levels.INFO)
    return
  end

  local items = {}
  for i, item in ipairs(files) do
    -- Extract basename from file's full path without extension
    local filename = item:match("^.+[/\\](.+)$") or item
    local basename = filename:match("^(.+)%.[^%.]*$") or filename

    table.insert(items, {
      idx = i,
      file = item,
      basename = basename,
      text = basename,
    })
  end

  table.sort(items, function(a, b)
    return a.file > b.file
  end)

  -- Check if we have any valid items
  if #items == 0 then
    vim.notify("No valid chat history files found", vim.log.levels.INFO)
    return
  end

  snacks.picker({
    actions = {
      delete_history_file = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        -- Confirm deletion
        vim.ui.select(
          { "Yes", "No" },
          { prompt = "Delete " .. vim.fn.fnamemodify(item.file, ":t") .. "?" },
          function(choice)
            if choice == "Yes" then
              -- Delete the file
              local success, err = os.remove(item.file)
              if success then
                vim.notify("Deleted: " .. item.file, vim.log.levels.INFO)
                -- Refresh the picker to show updated list
                picker:close()
                vim.schedule(function()
                  list_chat_history()
                end)
              else
                vim.notify("Failed to delete: " .. (err or "unknown error"), vim.log.levels.ERROR)
              end
            end
          end
        )
      end,
    },
    confirm = function(picker, item)
      picker:close()

      -- Verify file exists before loading
      if not vim.fn.filereadable(item.file) then
        vim.notify("Chat history file not found: " .. item.file, vim.log.levels.ERROR)
        return
      end

      vim.g.copilot_chat_title = item.basename

      new_chat_window("", {
        load = item.basename,
      })
    end,
    items = items,
    format = function(item)
      local formatted_title = decode_title(item.basename)
      local display = " " .. formatted_title

      local mtime = vim.fn.getftime(item.file)
      local date = T.fn.fmt_relative_time(mtime)

      return {
        { string.format("%-5s", date), "SnacksPickerLabel" },
        { display },
      }
    end,
    preview = function(ctx)
      local file = io.open(ctx.item.file, "r")
      if not file then
        ctx.preview:set_lines({ "Unable to read file" })
        return
      end

      local content = file:read("*a")
      file:close()

      local ok, messages = pcall(vim.json.decode, content, {
        luanil = {
          object = true,
          array = true,
        },
      })

      if not ok then
        ctx.preview:set_lines({ "vim.fn.json_decode error" })
        return
      end

      local config = chat.config
      local preview = {}
      for _, message in ipairs(messages or {}) do
        local header = message.role == "user" and config.question_header or config.answer_header
        table.insert(preview, header .. config.separator .. "\n")
        table.insert(preview, message.content .. "\n")
      end

      ctx.preview:highlight({ ft = "copilot-chat" })
      ctx.preview:set_lines(preview)
    end,
    sort = {
      fields = { "text:desc" },
    },
    title = "Copilot Chat History",
    win = {
      input = {
        keys = {
          ["dd"] = "delete_history_file", -- Use our custom action
        },
      },
    },
  })
end

return M
