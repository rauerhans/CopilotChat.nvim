local providers = require("CopilotChat.providers.")
local constants = require('CopilotChat.constants')
local notify = require('CopilotChat.notify')
local utils = require('CopilotChat.utils')
local curl = require('CopilotChat.utils.curl')
local files = require('CopilotChat.utils.files')

local function get_gemini_api_key()
  local api_key = os.getenv("GEMINI_API_KEY")
  if not api_key then
    error("GEMINI_API_KEY environment variable is not set")
  end
  return api_key
end

---@type table<string, CopilotChat.config.providers.Provider>
local M = {}

M.gemini = {

  get_headers = function()
    return {
      ["x-goog-api-key"] = get_gemini_api_key(),
      ["Content-Type"] = "application/json",
    }
  end,


  get_models = function(headers)
    local url = "https://generativelanguage.googleapis.com/v1beta/models"
    local response, err = utils.curl_get(url, {
      headers = headers,
      json_response = true,
    })

    if err then error(err) end

    return vim.iter(response.body.models or {})
        :filter(function(model)
          return vim.tbl_contains(model.supportedGenerationMethods or {}, "generateContent")
        end)
        :map(function(model)
          -- strip 'models/' prefix for the ID to match the format
          local id = model.name:gsub("^models/", "")
          return {
            id = id,
            name = model.displayName,
            -- sensible defaults for the plugin's tokenizer logic, if the models don't provide them (newer ones do)
            max_input_tokens = model.inputTokenLimit or 128000,
            max_output_tokens = model.outputTokenLimit or 4096,
            tokenizer = 'o200k_base', -- Closest approximation for token counting
          }
        end)
        :totable()
  end,

  prepare_input = function(inputs, opts)
    local contents = {}
    local system_instruction = nil

    for _, msg in ipairs(inputs) do
      if msg.role == "system" then
        -- gemini doesn't really have "system prompts"
        system_instruction = {
          parts = { { text = msg.content } }
        }
      else
        -- Map roles: assistant -> model, user -> user
        table.insert(contents, {
          role = (msg.role == "assistant" or msg.role == "model") and "model" or "user",
          parts = { { text = msg.content } }
        })
      end
    end

    return {
      contents = contents,
      system_instruction = system_instruction,
      generationConfig = {
        temperature = opts.temperature or 0.7,
        maxOutputTokens = opts.model.max_output_tokens,
      },
      -- use the stream_func
      stream = true,
    }
  end,


  prepare_output = function(output, opts)
    local result = {
      content = nil,
      finish_reason = nil,
      total_tokens = nil,
      references = {},
    }

    if not output.candidates or #output.candidates == 0 then
      return result
    end

    local candidate = output.candidates[1]

    -- extract text
    if candidate.content and candidate.content.parts and candidate.content.parts[1] then
      result.content = candidate.content.parts[1].text
    end

    -- finish reasons
    if candidate.finishReason then
      result.finish_reason = candidate.finishReason:lower()
      if result.finish_reason == "stop" then
        result.finish_reason = "stop"
      end
    end

    -- extract usage
    if output.usageMetadata then
      result.total_tokens = output.usageMetadata.totalTokenCount
    end

    return result
  end,


  get_url = function(opts)
    local model_id = opts.model.id or "gemini-1.5-flash"
    -- We use 'alt=sse' so the Gemini API returns Server-Sent Events (data: ...)
    -- which matches the standard parser in CopilotChat's client.lua
    return string.format(
      "https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?alt=sse",
      model_id
    )
  end,


}

return M
