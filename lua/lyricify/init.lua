local M = {}

local Async = require("lyricify.utils.async")
local Config = require("lyricify.config")
local Utils = require("lyricify.utils")

local timer = vim.uv.new_timer()
assert(timer)

local win = nil ---@type lyricify.Win?
local ticking = false

local active = true
local switch_mode

---@async
local function tick()
  if ticking then
    return
  end
  ticking = true

  Async.schedule()
  if not win or not win:valid() then
    win = Utils.win:new(Config.win.opts)
  end

  local state = require("lyricify.state")() ---@type lyricify.PlayerState?
  if state then
    local lyrics = require("lyricify.lyrics")(state.metadata) ---@type lyricify.lyrics.Result
    Async.schedule()
    win:show(lyrics:get(state.position))
  else
    Async.schedule()
    win:close()
  end

  switch_mode(state ~= nil)

  ticking = false
end

M.enabled = false

---@param value boolean
switch_mode = function(value)
  if value == active then
    return
  end
  if timer:is_active() then
    timer:stop()
  end
  timer:start(0, value and Config.interval or Config.inactive_interval, Async.void(tick))
  active = value
  Utils.debug("Turn into %s mode", active and "active" or "inactive")
end

function M.enable()
  if timer:is_active() then
    return
  end
  timer:start(0, Config.interval, Async.void(tick))
  M.enabled = true
end

function M.disable()
  if win then
    win:close()
  end
  if timer:is_closing() then
    return
  end
  timer:stop()
  M.enabled = false
end

function M.toggle()
  if M.enabled then
    M.disable()
  else
    M.enable()
  end
end

---@param opts? lyricify.config.Opts
function M.setup(opts)
  if vim.g.lyricify_loaded then
    return
  end
  vim.g.lyricify_loaded = true

  Config.setup(opts)

  if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = "LyricifyTranslation" })) then
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        vim.api.nvim_set_hl(0, "LyricifyTranslation", { link = "Comment", italic = false })
      end,
      group = Config.__augroup,
    })
    vim.api.nvim_set_hl(0, "LyricifyTranslation", { link = "Comment", italic = false })
  end

  require("lyricify.command").setup()

  vim.api.nvim_create_autocmd("TabEnter", {
    callback = function()
      if win then
        win:close()
      end
    end,
    group = Config.__augroup,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    callback = function()
      if M.enabled then
        M.enable()
      end
    end,
    group = Config.__augroup,
  })

  vim.api.nvim_create_autocmd("FocusLost", {
    callback = function()
      if M.enabled then
        -- NOTE: disable temporarily
        M.disable()
        M.enabled = true
      end
    end,
    group = Config.__augroup,
  })

  if Config.startup then
    require("lyricify").enable()
  end
end

return M
