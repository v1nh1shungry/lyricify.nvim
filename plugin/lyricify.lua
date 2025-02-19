if vim.fn.executable("playerctl") == 0 then
  error("`playerctl` is not executable")
end

vim.defer_fn(require("lyricify").setup, 500)
