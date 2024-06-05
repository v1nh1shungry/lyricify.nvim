local M = {}

local bufnr, winid

local timer = vim.uv.new_timer()

local config = {
  update_interval = 500,
  min_width = 40,
  max_width = 120,
  position = function(width, height)
    return 1, math.floor((vim.o.columns - width) / 2)
  end,
}

---@type vim.SystemObj
local job

local function try_launch_server()
  local root_dir = vim.fs.normalize(vim.fs.dirname(debug.getinfo(1).source:sub(2)) .. "/..")
  job = vim.system({
    "node",
    vim.fs.joinpath(root_dir, "server.js"),
  })
end

---@param text string
---@param width integer
local function padding(text, width)
  local padding_length = math.floor((width - vim.fn.strdisplaywidth(text)) / 2)
  return (" "):rep(padding_length) .. text .. (" "):rep(padding_length)
end

local ns = vim.api.nvim_create_namespace("lyricify_nvim_ns")

local function update()
  vim.system(
    {
      "curl",
      "-m",
      "1",
      "localhost:12138",
    },
    { text = true },
    vim.schedule_wrap(function(obj)
      if obj.code == 0 then
        if not vim.api.nvim_win_is_valid(winid) then
          timer:stop()
          return
        end
        local res = vim.json.decode(obj.stdout, { luanil = { object = true, array = true } })
        local lines = {}
        if res.error then
          lines = { res.error }
        else
          lines = { res.lyric, res.tlyric }
        end
        local width = config.min_width
        for _, l in ipairs(lines) do
          width = math.max(vim.fn.strdisplaywidth(l), width)
        end
        width = math.min(config.max_width, math.max(config.min_width, width))
        for i, l in ipairs(lines) do
          lines[i] = padding(l, width)
        end
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
        if #lines == 2 then
          vim.highlight.range(bufnr, ns, "Comment", { 1, 0 }, { 1, string.len(lines[2]) })
        end
        local row, col = config.position(width, #lines)
        vim.api.nvim_win_set_config(winid, {
          hide = false,
          relative = "editor",
          height = #lines,
          width = width,
          row = row,
          col = col,
        })
      else
        try_launch_server()
      end
    end)
  )
end

function M.show()
  if timer:is_active() then
    return
  end
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
  end
  if winid == nil or not vim.api.nvim_win_is_valid(winid) then
    winid = vim.api.nvim_open_win(bufnr, false, {
      relative = "editor",
      width = config.min_width,
      height = 1,
      row = 1,
      col = math.floor((vim.o.columns - config.min_width) / 2),
      title = "lyricify.nvim",
      title_pos = "center",
      border = "rounded",
      style = "minimal",
      focusable = false,
      hide = true,
    })
  end
  timer:start(0, config.update_interval, update)
end

function M.hide()
  if timer:is_active() then
    timer:stop()
    if winid and vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, false)
    end
  end
end

function M.toggle()
  if timer:is_active() then
    M.hide()
  else
    M.show()
  end
end

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts)

  vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
      if job and not job:is_closing() then
        job:kill(9)
      end
    end,
    group = vim.api.nvim_create_augroup("lyricify_nvim_autocmds", {}),
  })
end

return M
