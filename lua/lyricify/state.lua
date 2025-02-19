-- TODO: use playerctl library instead of executable

local Async = require("lyricify.utils.async")
local Config = require("lyricify.config")
local Utils = require("lyricify.utils")

---@class lyricify.Player: lyricify.Object
---@field name string
local Player = Utils.class("Player")

---@class lyricify.Metadata: lyricify.Object
---@field title string
---@field artist string
---@field duration number
local Metadata = Utils.class("Metadata")

---@param title string
---@param artist string
---@param duration number
function Metadata:initialize(title, artist, duration)
  self.title = title
  self.artist = artist
  self.duration = duration
end

function Metadata:filename()
  return vim.fn.fnameescape(
    vim.fs.joinpath(Config.__cache_dir, table.concat({ self.title, self.artist }, "__"):gsub("/", "%%") .. ".json")
  )
end

---@param name string
function Player:initialize(name)
  self.name = name
end

---@class lyricify.PlayerState
---@field status "Playing" | "Paused"
---@field position number
---@field metadata lyricify.Metadata

---@async
---@return lyricify.PlayerState?
function Player:state()
  local res = Async.system({
    "playerctl",
    "--player",
    self.name,
    "metadata",
    "--format",
    "{{status}}@{{position}}@{{title}}@{{artist}}@{{mpris:length}}",
  })
  if res.code ~= 0 and not res.stderr:find("No player") then
    Utils.error("Failed to get player [%s] metadata: %s", self.name, res.stderr)
    return nil
  end

  local properties = vim.iter(vim.split(res.stdout, "@")):map(vim.trim):totable()
  if #properties ~= 5 then
    return nil
  end

  return {
    status = properties[1],
    position = tonumber(properties[2]) / 1000,
    metadata = Metadata:new(properties[3], properties[4], properties[5] / 1000),
  }
end

local current_playing = nil ---@type lyricify.Player?

---@async
---@return lyricify.Player?
---@return lyricify.PlayerState?
local function get_current_playing()
  local res = Async.system({ "playerctl", "-l" })
  if res.code ~= 0 then
    Utils.error("Failed to list players: " .. res.stderr)
    return nil
  end

  if res.stdout:find("No player") then
    return nil
  end

  for _, name in ipairs(vim.split(res.stdout, "\n", { trimempty = true })) do
    local player = Player:new(name)
    local state = player:state()
    if state and state.status == "Playing" then
      return player, state
    end
  end

  return nil
end

return setmetatable({}, {
  ---@async
  ---@return lyricify.PlayerState?
  __call = function()
    local state = current_playing and current_playing:state() ---@type lyricify.PlayerState?
    if not state or state.status == "Paused" then
      current_playing, state = get_current_playing()
      if not current_playing then
        return nil
      end
    end
    return state
  end,
})
