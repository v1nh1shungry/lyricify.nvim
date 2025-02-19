local Class = require("lyricify.utils.class")
local Config = require("lyricify.config")

---@class lyricify.Win: lyricify.Object
---@field buf integer
---@field id integer
local Win = Class("Win")

---@param value number
---@return integer
local function resolve_width(value)
  return math.floor(value >= 1 and value or vim.o.columns * value)
end

---@param value integer[] | integer[] | fun(width: integer, height: integer): integer[]
---@param width integer
---@param height integer
---@return integer row
---@return integer col
local function resolve_pos(value, width, height)
  ---@diagnostic disable-next-line: redundant-return-value, param-type-mismatch
  return unpack(type(value) == "function" and value(width, height) or value)
end

---@param opts? vim.api.keyset.win_config
function Win:initialize(opts)
  local width = resolve_width(Config.win.width)
  local row, col = resolve_pos(Config.win.pos, width, 1)

  opts = vim.tbl_deep_extend("force", Config.win.opts, {
    width = width,
    height = 1,
    row = row,
    col = col,
  }, opts or {})

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, opts)

  vim.bo[buf].bufhidden = "wipe"
  vim.iter(Config.win.wo):each(function(k, v)
    vim.wo[win][k] = v
  end)

  self.buf = buf
  self.id = win
end

---@param opts vim.api.keyset.win_config
function Win:config(opts)
  if not self:valid() then
    return
  end
  opts = vim.tbl_deep_extend("force", vim.api.nvim_win_get_config(self.id), opts)
  vim.api.nvim_win_set_config(self.id, opts)
end

---@param lines string[]
function Win:show(lines)
  if not self:valid() then
    return
  end

  local width = vim.iter(lines):fold(resolve_width(Config.win.width), function(acc, v) ---@type integer
    return math.max(acc, vim.fn.strdisplaywidth(v) + 2)
  end)

  lines = vim
    .iter(lines)
    :map(function(v)
      local padding_length = math.floor((width - vim.fn.strdisplaywidth(v)) / 2)
      return (" "):rep(padding_length) .. v .. (" "):rep(padding_length)
    end)
    :totable()

  vim.api.nvim_buf_clear_namespace(self.buf, Config.__ns, 0, -1)

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, lines)
  vim.api.nvim_buf_set_extmark(self.buf, Config.__ns, 0, 0, { line_hl_group = "LyricifyOriginal" })
  if #lines == 2 then
    vim.api.nvim_buf_set_extmark(self.buf, Config.__ns, 1, 0, { line_hl_group = "LyricifyTranslation" })
  end

  local row, col = resolve_pos(Config.win.pos, width, #lines)
  self:config({
    width = width,
    height = #lines,
    hide = false,
    row = row,
    col = col,
  })
end

function Win:close()
  if self:valid() then
    vim.api.nvim_win_close(self.id, true)
  end
end

---@return boolean
function Win:valid()
  return vim.api.nvim_win_is_valid(self.id)
end

return Win
