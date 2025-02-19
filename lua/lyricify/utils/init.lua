---@class lyricify.utils
---@field async lyricify.utils.Async
---@field class lyricify.Object
---@field t2s fun(s: string): string
---@field win lyricify.Win
local M = {}

---@param level string
---@return fun(msg: string, ...)
local function notify_fn(level)
  return function(msg, ...)
    local args = vim.F.pack_len(...)
    vim.notify(
      args.n == 0 and msg or msg:format(vim.F.unpack_len(args)),
      vim.log.levels[level:upper()],
      { title = "lyricify.nvim" }
    )
  end
end

return setmetatable(M, {
  __index = function(_, k)
    if k == "debug" then
      M[k] = require("lyricify.config").debug and notify_fn(k) or function() end
    elseif vim.list_contains({ "error", "info", "warn" }, k) then
      M[k] = notify_fn(k)
    else
      M[k] = vim.F.npcall(require, "lyricify.utils." .. k)
    end
    return M[k]
  end,
})
