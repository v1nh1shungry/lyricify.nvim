---@class lyricify.command
local M = {}

local Lyrics = require("lyricify.lyrics")

---@class lyricify.command.Subcommand
---@field candidates? string[]
---@field handler fun(args?: string)

M.subcommands = { ---@type table<string, lyricify.command.Subcommand>
  clear = {
    candidates = { "all", "this" },
    handler = function(args)
      Lyrics.clear(args == "all")
    end,
  },
  refresh = {
    handler = function()
      Lyrics.refresh()
    end,
  },
  shift = {
    handler = function(args)
      require("lyricify.utils").info("Current time shift: `%d` ms", Lyrics.shift(args and tonumber(args)))
    end,
  },
  toggle = {
    handler = function()
      require("lyricify").toggle()
    end,
  },
}

function M.setup()
  vim.api.nvim_create_user_command("Lyricify", function(command_args)
    local args = vim.split(command_args.args, " ", { trimempty = true })
    args = #args == 0 and { "toggle" } or args
    local subcommand = M.subcommands[args[1]]
    assert(subcommand, ("Abort: unknown subcommand %q"):format(args[1]))
    local max_n = subcommand.candidates and 1 or 0
    assert(
      #args - 1 <= max_n,
      ("Abort: subcommand %q accepts at most %d argument%s"):format(args[1], max_n, max_n > 1 and "s" or "")
    )
    assert(
      not args[2] or not subcommand.candidates or vim.list_contains(subcommand.candidates, args[2]),
      ("Abort: unknown argument %q for subcommand %q"):format(args[2], args[1])
    )
    subcommand.handler(args[2])
  end, {
    nargs = "*",
    complete = function(lead, cmdline)
      local pieces = vim.split(cmdline, " ", { trimempty = true })
      local function resolve(subcommand, candidates)
        return vim
          .iter(candidates)
          :filter(function(s)
            return s ~= subcommand and vim.startswith(s, lead)
          end)
          :totable()
      end

      if #pieces <= 3 then
        local subcommands = vim.tbl_keys(M.subcommands)
        if #pieces <= 2 and not vim.list_contains(subcommands, pieces[2]) then
          return resolve(pieces[2], subcommands)
        end
        local candidates = M.subcommands[pieces[2]].candidates or {}
        if not vim.list_contains(candidates, pieces[3]) then
          return resolve(pieces[3], candidates)
        end
      end

      return {}
    end,
  })
end

return M
