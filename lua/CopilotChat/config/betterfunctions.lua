local resources = require('CopilotChat.resources')
local utils = require('CopilotChat.utils')
local files = require('CopilotChat.utils.files')

local M = {}

M.buffer = {
  group = "copilot",
  uri = "buffer://{name}",
  description = "Retrieves content from a specific buffer.",
  schema = {
    type = "object",
    required = { "name" },
    properties = {
      name = {
        type = "string",
        description = "Buffer filename to include in chat context.",
        enum = function()
          local chat_winid = vim.api.nvim_get_current_win()
          local async = require("plenary.async")
          local fn = async.wrap(function(callback)
            Snacks.picker.buffers({
              confirm = function(picker, item)
                picker:close()
                -- Return focus to the chat window
                if vim.api.nvim_win_is_valid(chat_winid) then
                  vim.api.nvim_set_current_win(chat_winid)
                  vim.cmd("normal! a")
                end
                callback({ item.file })
              end,
            })
          end, 1)
          return fn()
        end,
      },
    },
  },
  resolve = function(input, source)
    utils.schedule_main()
    local name = input.name or vim.api.nvim_buf_get_name(source.bufnr)
    local found_buf = nil
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buf) == name then
        found_buf = buf
        break
      end
    end

    if not found_buf then
      error("Buffer not found: " .. name)
    end

    local data, mimetype = resources_get_buffer(found_buf)
    if not data then
      error("Buffer not found: " .. name)
    end

    return {
      {
        uri = "buffer://" .. name,
        name = name,
        mimetype = mimetype,
        data = data,
      },
    }
  end,
}

M.file = {
  group = "copilot",
  uri = "file://{path}",
  description = "Pick a file to include in chat context.",
  resolve = function(input)
    utils.schedule_main()
    local data, mimetype = resources.get_file(input.path)
    if not data then
      error("File not found: " .. input.path)
    end

    return {
      {
        uri = "file://" .. input.path,
        name = input.path,
        mimetype = mimetype,
        data = data,
      },
    }
  end,
  schema = {
    type = "object",
    required = { "path" },
    properties = {
      path = {
        type = "string",
        description = "Path to file to include in chat context.",
        enum = function()
          local chat_winid = vim.api.nvim_get_current_win()
          local async = require("plenary.async")
          local fn = async.wrap(function(callback)
            Snacks.picker.smart({
              confirm = function(picker, item)
                picker:close()
                -- Return focus to the chat window
                if vim.api.nvim_win_is_valid(chat_winid) then
                  vim.api.nvim_set_current_win(chat_winid)
                  vim.cmd("normal! a")
                end
                callback({ item.file })
              end,
            })
          end, 1)
          return fn()
        end,
      },
    },
  },
}

M.gitdiff = {
  group = "copilot",
  uri = "git://diff/{target}",
  description =
  "Retrieves git diff information. Requires git to be installed. Useful for discussing code changes or explaining the purpose of modifications.",
  schema = {
    type = "object",
    required = { "target" },
    properties = {
      target = {
        type = "string",
        description = "Target to diff against.",
        enum = { "unstaged", "staged", "<sha>" },
        default = "unstaged",
      },
    },
  },
  resolve = function(input, source)
    local cmd = { "git", "-C", source.cwd(), "diff", "--no-color", "--no-ext-diff" }

    if input.target == "staged" then
      table.insert(cmd, "--staged")
    elseif input.target == "unstaged" then
      table.insert(cmd, "--")
    else
      table.insert(cmd, input.target)
    end

    local EXCLUDE_FILES = { "package-lock.json", "lazy-lock.json", "Cargo.lock" }
    for _, file in ipairs(EXCLUDE_FILES) do
      table.insert(cmd, ":(exclude)" .. file)
    end

    local out = utils.system(cmd)

    return {
      {
        uri = "git://diff/" .. input.target,
        mimetype = "text/plain",
        data = out.stdout,
      },
    }
  end,
}

return M
