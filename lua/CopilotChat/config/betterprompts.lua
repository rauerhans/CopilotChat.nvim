local M = {}

M.FILETYPE_CONFIGS = {
  angular = {
    patterns = {
      "%.component%.ts$",
      "%.component%.html$",
      "%.module%.ts$",
      "%.directive%.ts$",
      "%.pipe%.ts$",
      "%.service%.ts$",
      "%.guard%.ts$",
      "%.resolver%.ts$",
      "%.injectable%.ts$",
    },
    filetypes = { "htmlangular" },
    priority = 1000,
    prompts = { "angular" },
  },
  ansible = {
    filetypes = { "yaml" },
    prompts = { "ansible" },
  },
  css = {
    filetypes = { "css", "scss", "less" },
    patterns = {
      "%.css$",
      "%.scss$",
      "%.module%.css$",
    },
    prompts = { "css" },
  },
  dockerfile = {
    filetypes = { "dockerfile" },
    prompts = { "docker" },
  },
  javascript = {
    filetypes = { "javascript" },
    prompts = { "js" },
  },
  neovim = {
    filetypes = { "lua" },
    prompts = { "neovim", "lua" },
  },
  nushell = {
    filetypes = { "nu" },
    prompts = { "nushell" },
  },
  playwright = {
    patterns = { "%.spec%.ts$" },
    priority = 5000,
    prompts = { "playwright" },
  },
  python = {
    filetypes = { "python" },
    prompts = { "python" },
  },
  rust = {
    filetypes = { "rust" },
    prompts = { "rust" },
  },
  storybook = {
    alernate = ".tsx",
    patterns = { "%.stories%.tsx$" },
    priority = 5000,
    prompts = { "storybook" },
  },
  reacttest = {
    alternate = ".tsx",
    patterns = { "%.test%.tsx$" },
    priority = 4000,
    prompts = { "reacttest" },
  },
  typescripttest = {
    alternate = ".ts",
    patterns = { "%.test%.ts$" },
    priority = 3000,
    prompts = { "tstest" },
  },
  react = {
    filetypes = { "typescriptreact" },
    priority = 2000,
    prompts = { "react" },
  },
  typescript = {
    filetypes = { "typescript" },
    prompts = { "ts" },
  },
  vim = {
    filetypes = { "vim" },
    prompts = { "vimscript" },
  },
}

M.read_prompt_file = function(basename)
  local config_dir = tostring(vim.fn.stdpath("config"))
  local prompt_dir = vim.fs.joinpath(config_dir, "prompts")
  local file_path = vim.fs.joinpath(prompt_dir, string.format("%s.md", string.lower(basename)))
  if not vim.fn.filereadable(file_path) then
    return ""
  end

  return table.concat(vim.fn.readfile(file_path), "\n")
end

M.load_prompts = function(prompt_dir)
  local prompts = {}
  local prompt_files = vim.fn.glob(prompt_dir .. "/*.md", false, true)

  for _, file_path in ipairs(prompt_files) do
    local basename = vim.fn.fnamemodify(file_path, ":t:r")
    local prompt = read_prompt_file(basename)
    prompts[basename] = {
      prompt = prompt,
      system_prompt = prompt,
    }
  end

  return prompts
end

M.get_alternate_file = function(file_ext, alternate_ext)
  local current_file = vim.fn.expand("%:p")
  local source_file = current_file:gsub(file_ext, alternate_ext)
  if vim.fn.filereadable(source_file) == 1 then
    -- Convert to path relative to cwd
    local cwd = vim.fn.getcwd()
    local relative_path = source_file:gsub("^" .. vim.pesc(cwd) .. "/", "")
    return relative_path
  end
  return nil
end

M.get_config_by_filetype = function()
  local ft = vim.bo.filetype
  local filename = vim.fn.expand("%:t")

  -- Sort FILETYPE_CONFIGS by priority, descending
  local sorted_configs = {}
  for _, config in pairs(FILETYPE_CONFIGS) do
    table.insert(sorted_configs, config)
  end
  table.sort(sorted_configs, function(a, b)
    local a_priority = a.priority or 0
    local b_priority = b.priority or 0
    return a_priority > b_priority
  end)

  for _, config in pairs(sorted_configs) do
    local matches = false

    -- Check file patterns if defined
    if config.patterns then
      for _, pattern in ipairs(config.patterns) do
        if filename:match(pattern) then
          matches = true
          break
        end
      end
    end

    -- Check filetypes
    if not matches and config.filetypes and vim.tbl_contains(config.filetypes, ft) then
      matches = true
    end

    if matches then
      if config.prompts then
        if type(config.prompts) == "function" then
          config.prompts = config.prompts()
        else
          config.prompts = config.prompts
        end
      end

      -- Check if alternate file exists and add as context prompt
      if config.alternate then
        -- For each pattern, try to find the alternate file
        for _, pattern in ipairs(config.patterns or {}) do
          local alternate = get_alternate_file(pattern, config.alternate)
          if alternate then
            config.prompts = config.prompts or {}
            table.insert(config.prompts, #config.prompts + 1, "#file:" .. alternate)
          end
        end
      end

      return config
    end
  end
end

M.get_system_prompt = function(action)
  local base_prompt = (action == "explain") and "COPILOT_EXPLAIN"
      or (action == "generic" and "COPILOT_INSTRUCTIONS")
      or "COPILOT_GENERATE"

  return base_prompt
end

M.get_sticky_prompts = function()
  local sticky = {}

  -- Get filetype-specific prompts
  local ft_config = get_config_by_filetype()
  local prompts = ft_config and ft_config.prompts or {}

  -- Add filetype-specific prompts
  for _, p in pairs(prompts) do
    -- Only ad a slash if prompt not started by #, $, / or @
    if not p:match("^[#$/@]") then
      p = "/" .. p
    end
    table.insert(sticky, p)
  end

  return sticky
end

return M
