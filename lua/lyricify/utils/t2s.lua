local ffi = require("ffi")

ffi.cdef([[
void *opencc_open(const char *);
char *opencc_convert_utf8(void *, const char *, size_t);
void opencc_convert_utf8_free(char *);
int opencc_close(void *);
]])

local opencc = ffi.load("opencc")

---@param s string
---@return string
return function(s)
  if not opencc then
    return s
  end
  local cc = opencc.opencc_open("t2s.json")
  local converted = opencc.opencc_convert_utf8(cc, s, s:len())
  local res = ffi.string(converted)
  opencc.opencc_convert_utf8_free(converted)
  opencc.opencc_close(cc)
  return res
end
