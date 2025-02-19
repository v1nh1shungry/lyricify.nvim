---@class lyricify.config.Network
---@field timeout integer Connect timeout in milliseconds.
---@field retries integer

---@class lyricify.config.Win
---@field opts vim.api.keyset.win_config `:help nvim_open_win()`
---@field pos integer[] | fun(width: integer, height: integer): integer[] Lyrics window's position.
---@field width number Default width of the lyrics window.
---@field wo vim.wo | {} `:help vim.wo`

---@class lyricify.config.Opts
---@field debug boolean Enable printing useful for debug purpose.
---@field diff_time integer Time difference maximum in milliseconds between lyrics' duration and actual duration.
---@field interval integer Interval in milliseconds to update the lyrics.
---@field inactive_interval integer Interval in milliseconds when no playing player.
---@field network lyricify.config.Network
---@field shift_time integer | fun(actual_duration: integer, lyric_duration: integer): integer Shift time in milliseconds.
---@field startup boolean Automatically enable after the plugin loads.
---@field win lyricify.config.Win
local DEFAULT_CONFIG = {
  debug = false,
  diff_time = 1000,
  interval = 500,
  inactive_interval = 2000,
  network = { timeout = 1000, retries = 3 },
  shift_time = 0,
  startup = true,
  win = {
    opts = {
      relative = "editor",
      title_pos = "center",
      title = "lyricify.nvim",
      border = "rounded",
      style = "minimal",
      focusable = false,
      hide = true,
    },
    pos = function(width, _)
      return {
        (vim.iter(vim.api.nvim_list_wins()):any(function(w)
          return vim.wo[w].winbar ~= ""
        end) and 1 or 0) + (vim.o.tabline == "" and 0 or 1),
        math.floor((vim.o.columns - width) / 2),
      }
    end,
    width = 0.3,
    wo = { winblend = 20 },
  },
}

local VALIDATION_TABLE = { ---@type table<string, type | type[]>
  debug = "boolean",
  diff_time = "number",
  interval = "number",
  inactive_interval = "number",
  ["network.timeout"] = "number",
  ["network.retries"] = "number",
  shift_time = { "number", "function" },
  startup = "boolean",
  ["win.opts"] = "table",
  ["win.pos"] = { "table", "function" },
  ["win.width"] = "number",
  ["win.wo"] = "table",
}

---@class lyricify.config: lyricify.config.Opts
local M = {
  __augroup = vim.api.nvim_create_augroup("lyricify.nvim", {}),
  __cache_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "lyricify"),
  __ns = vim.api.nvim_create_namespace("lyricify.nvim"),
}

---@param opts lyricify.config.Opts
---@param prefix? string
local function validate(opts, prefix)
  for k, v in pairs(opts) do
    local key = (prefix and (prefix .. ".") or "") .. k
    if VALIDATION_TABLE[key] then
      vim.validate(k, v, VALIDATION_TABLE[key])
    elseif type(v) == "table" then
      validate(v, k)
    else
      error(("unkown configuration field `%s`"):format(key))
    end
  end
end

---@param opts? lyricify.config.Opts
function M.setup(opts)
  opts = opts or {}
  validate(opts)
  M.options = vim.tbl_deep_extend("force", DEFAULT_CONFIG, opts)
end

return setmetatable(M, {
  __index = function(_, k)
    if not rawget(M, "options") then
      M.setup()
    end
    local opts = rawget(M, "options")
    return k == "options" and opts or opts[k]
  end,
})
