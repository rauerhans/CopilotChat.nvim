if vim.g.loaded_copilot_chat then
  return
end

local min_version = '0.10.0'
if vim.fn.has('nvim-' .. min_version) ~= 1 then
  vim.notify_once(('CopilotChat.nvim requires Neovim >= %s'):format(min_version), vim.log.levels.ERROR)
  return
end

local group = vim.api.nvim_create_augroup('CopilotChat', {})

-- Setup highlights
local function setup_highlights()
  vim.api.nvim_set_hl(0, 'CopilotChatHeader', { link = '@markup.heading.2.markdown', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatSeparator', { link = '@punctuation.special.markdown', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatSelection', { link = 'Visual', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatStatus', { link = 'DiagnosticHint', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatHelp', { link = 'DiagnosticInfo', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatResource', { link = 'Constant', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatTool', { link = 'Function', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatPrompt', { link = 'Statement', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatModel', { link = 'Type', default = true })
  vim.api.nvim_set_hl(0, 'CopilotChatUri', { link = 'Underlined', default = true })

  vim.api.nvim_set_hl(0, 'CopilotChatAnnotation', { link = 'ColorColumn', default = true })
  local fg = vim.api.nvim_get_hl(0, { name = 'CopilotChatStatus', link = false }).fg
  local bg = vim.api.nvim_get_hl(0, { name = 'CopilotChatAnnotation', link = false }).bg
  vim.api.nvim_set_hl(0, 'CopilotChatAnnotationHeader', { fg = fg, bg = bg })
end
vim.api.nvim_create_autocmd('ColorScheme', {
  group = group,
  callback = function()
    setup_highlights()
  end,
})
setup_highlights()

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'copilot-chat',
  group = group,
  callback = vim.schedule_wrap(function()
    vim.cmd.syntax('match CopilotChatResource "#\\S\\+"')
    vim.cmd.syntax('match CopilotChatTool "@\\S\\+"')
    vim.cmd.syntax('match CopilotChatPrompt "/\\S\\+"')
    vim.cmd.syntax('match CopilotChatModel "\\$\\S\\+"')
    vim.cmd.syntax('match CopilotChatUri "##\\S\\+"')
  end),
})

-- Setup commands
vim.api.nvim_create_user_command('CopilotChat', function(args)
  local chat = require('CopilotChat')
  local input = args.args
  if input and vim.trim(input) ~= '' then
    chat.ask(input)
  else
    chat.open()
  end
end, {
  nargs = '*',
  force = true,
  range = true,
})
vim.api.nvim_create_user_command('CopilotChatPrompts', function()
  local chat = require('CopilotChat')
  chat.select_prompt()
end, { force = true, range = true })
vim.api.nvim_create_user_command('CopilotChatModels', function()
  local chat = require('CopilotChat')
  chat.select_model()
end, { force = true })
vim.api.nvim_create_user_command('CopilotChatOpen', function()
  local chat = require('CopilotChat')
  chat.open()
end, { force = true })
vim.api.nvim_create_user_command('CopilotChatClose', function()
  local chat = require('CopilotChat')
  chat.close()
end, { force = true })
vim.api.nvim_create_user_command('CopilotChatToggle', function()
  local chat = require('CopilotChat')
  chat.toggle()
end, { force = true })
vim.api.nvim_create_user_command('CopilotChatStop', function()
  local chat = require('CopilotChat')
  chat.stop()
end, { force = true })
vim.api.nvim_create_user_command('CopilotChatReset', function()
  local chat = require('CopilotChat')
  chat.reset()
end, { force = true })
vim.api.nvim_create_user_command('CopilotChatHistory', function()
  local chat = require('CopilotChat')
  chat.load_history()
end, { force = true })


-- open chat
vim.api.nvim_create_user_command('CopilotChatAssistance', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("assistance")
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatGeneric', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("generic")
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatSearch', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("search")
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatArchitect', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("architect")
end, { force = true })

-- open chat inline
vim.api.nvim_create_user_command('CopilotChatAssistance', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("assistance", { inline = true })
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatGeneric', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("generic", { inline = true })
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatSearch', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("search", { inline = true })
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatArchitect', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("architect", { inline = true })
end, { force = true })


-- actions
vim.api.nvim_create_user_command('CopilotChatExplain', function()
  local chat = require('CopilotChat.extensions')
  chat.action("explain")
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatFix', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("fix")
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatImplement', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("implement")
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatOptimize', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("optimize")
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatReview', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("review")
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatRefactor', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("refactor")
end, { force = true })

-- actions inline
vim.api.nvim_create_user_command('CopilotChatExplain', function()
  local chat = require('CopilotChat.extensions')
  chat.action("explain", { inline = true })
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatFix', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("fix", { inline = true })
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatImplement', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("implement", { inline = true })
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatOptimize', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("optimize", { inline = true })
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatReview', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("review", { inline = true })
end, { force = true })

vim.api.nvim_create_user_command('CopilotChatRefactor', function()
  local chat = require('CopilotChat.extensions')
  chat.open_chat("refactor", { inline = true })
end, { force = true })

-- list chat history
vim.api.nvim_create_user_command('CopilotChatHistory', function()
  local chat = require('CopilotChat.extensions')
  chat.list_chat_history()
end, { force = true })



-- create co
vim.api.nvim_create_user_command("CopilotChatCommitMessage", function()
  local chat = require("CopilotChat")
  local bufnr = vim.api.nvim_get_current_buf()

  -- Determine which prompt command to use based on work environment
  local is_work_env = vim.fn.getenv("IS_WORK") == "true"
  local prompt = "/" .. (is_work_env and "commitwork" or "commit")

  chat.reset() -- Reset previous chat state

  vim.fn.start_spinner(bufnr, "Generating commit message...")

  chat.ask(prompt, {
    callback = function(response)
      vim.fn.stop_spinner(bufnr)

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
    context = { "git_staged" },
    headless = true,
    model = vim.fn.getenv("COPILOT_MODEL_CHEAP"),
    system_prompt = "/COPILOT_INSTRUCTIONS",
  })
end, {})

vim.api.nvim_create_user_command("CopilotCodeChatReview", function()
  local chat = require("CopilotChat")

  chat.reset() -- Reset previous chat state

  chat.ask("/review", {
    callback = function(response)
      local function accept_code_review()
        vim.keymap.del("n", "<c-]>", { buffer = true })

        chat.close()

        vim.api.nvim_win_close(0, false)
        vim.cmd("vertical Git")
        vim.cmd("Git commit")
      end

      vim.keymap.set("n", "<c-]>", accept_code_review, { buffer = true })
      return response
    end,
    context = { "git_staged" },
    model = vim.fn.getenv("COPILOT_MODEL_REASON"),
    selection = false,
    system_prompt = "/COPILOT_REVIEW",
    window = {
      layout = "replace",
    },
  })
end, {})

vim.api.nvim_create_user_command("CopilotChatPrReview", function()
  local snacks = require("snacks")
  local branches = vim.git.list_remote_branches()

  local items = {}
  for i, branch in ipairs(branches) do
    table.insert(items, {
      idx = i,
      file = branch.name,
      text = branch.name,
      time = branch.time,
    })
  end

  snacks.picker({
    title = "Select a branch to review",
    items = items,
    layout = {
      preset = "vertical",
      hidden = { "preview" },
    },
    format = function(item)
      local time = vim.fn.fmt_relative_time(item.time)

      return {
        { string.format("%-5s", time), "SnacksPickerLabel" },
        { item.file },
      }
    end,
    confirm = function(picker, item)
      picker:close()

      vim.git.diff_branch(item.text, function(diff)
        local prompt = table.concat({
          "> /review",
          " ",
          "```gitcommit",
          table.concat(diff.commit_lines, "\n"),
          "```",
          " ",
          "```diff",
          table.concat(diff.diff_lines, "\n"),
          "```",
        }, "\n")

        vim.schedule(function()
          new_chat_window(prompt, {
            model = vim.fn.getenv("COPILOT_MODEL_REASON"),
            selection = false,
            system_prompt = "/COPILOT_INSTRUCTIONS",
          })
        end)
      end)
    end,
  })
end, {})




local function complete_load()
  local chat = require('CopilotChat')
  local options = vim.tbl_map(function(file)
    return vim.fn.fnamemodify(file, ':t:r')
  end, vim.fn.glob(chat.config.history_path .. '/*', true, true))

  if not vim.tbl_contains(options, 'default') then
    table.insert(options, 1, 'default')
  end

  return options
end
--vim.api.nvim_create_user_command('CopilotChatSave', function(args)
--  local chat = require('CopilotChat')
--  chat.save(args.args)
--end, { nargs = '*', force = true, complete = complete_load })
vim.api.nvim_create_user_command('CopilotChatSave', function(args)
  local chat = require('CopilotChat')
  local name = args.args and vim.trim(args.args) or nil
  if name and name ~= '' then
    chat.save(name)
  else
    chat.auto_save()
  end
end, {
  nargs = '?',
  desc = 'Save current conversation',
})

vim.api.nvim_create_user_command('CopilotChatLoad', function(args)
  local chat = require('CopilotChat')
  chat.load(args.args)
end, { nargs = '*', force = true, complete = complete_load })



-- Store the current directory to window when directory changes
-- I dont think there is a better way to do this that functions
-- with "rooter" plugins, LSP and stuff as vim.fn.getcwd() when
-- i pass window number inside doesnt work
vim.api.nvim_create_autocmd({ 'VimEnter', 'WinEnter', 'DirChanged' }, {
  group = group,
  callback = function()
    vim.w.cchat_cwd = vim.fn.getcwd()
  end,
})

-- Setup treesitter
vim.treesitter.language.register('markdown', 'copilot-chat')

vim.g.loaded_copilot_chat = true
