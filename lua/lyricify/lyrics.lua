local Async = require("lyricify.utils.async")
local Class = require("lyricify.utils.class")
local Config = require("lyricify.config")
local Utils = require("lyricify.utils")

---@class lyricify.lyrics.Base: lyricify.Object
local Base = Class("lyrics.Base")

---@class lyricify.lyrics.Error: lyricify.lyrics.Base
---@field what string
local Error = Class("lyrics.Error", Base)

---@param what? string
function Error:initialize(what)
  self.what = what or ""
end

---@return string[]
function Error:get()
  return { self.what }
end

Error.NONE = Error:new()
Error.UNREACHABLE = Error:new("网络中断，请检查连接")
Error.SONG_NOT_FOUND = Error:new("歌曲消失在茫茫的曲库中了")
Error.LYRICS_NOT_FOUND = Error:new("歌词消失在茫茫的词库中了")

---@class lyricify.lyrics.RetriableNetworkError: lyricify.lyrics.Error
---@field retries integer
local RetriableNetworkError = Class("lyrics.RetriableNetworkError", Error)

---@param retries integer
function RetriableNetworkError:initialize(retries)
  Error.initialize(self, "网络异常，重试中……")
  self.retries = retries
end

---@return boolean
function RetriableNetworkError:retriable()
  return self.retries > 0
end

---@return lyricify.lyrics.Error
function RetriableNetworkError:unreachable()
  self.retries = self.retries - 1
  return self.retries == 0 and vim.deepcopy(Error.UNREACHABLE) or self
end

Error.TEMPORARY_UNREACHABLE = RetriableNetworkError:new(Config.network.retries)

---@class lyricify.Lyric
---@field start number
---@field text string

---@class lyricify.lyrics.Result: lyricify.lyrics.Base
---@field original lyricify.Lyric[]
---@field translation lyricify.Lyric[]
---@field shift_time integer
local Result = Class("lyrics.Result", Base)

---@param original lyricify.Lyric[]
---@param translation lyricify.Lyric[]
---@param shift_time integer
function Result:initialize(original, translation, shift_time)
  self.original = original
  self.translation = translation
  self.shift_time = shift_time
end

---@param position number
---@return string[]
function Result:get(position)
  position = position + self.shift_time

  local original = vim.iter(self.original):rfind(function(l) ---@type lyricify.Lyric
    return position >= l.start
  end)

  if not original then
    return { "♪♪♪" }
  end

  local translation = vim.iter(self.translation):rfind(function(l) ---@type lyricify.Lyric
    return position >= l.start
  end)

  return { original.text, (translation and translation.text ~= "") and translation.text or nil }
end

---@param filename string
function Result:save(filename)
  vim.fn.writefile({ vim.json.encode(self) }, filename)
end

---@param value? integer
---@return integer
function Result:shift(value)
  if not value then
    return self.shift_time
  end
  self.shift_time = self.shift_time + value
  return self.shift_time
end

---@param lyric string
---@return lyricify.Lyric[]
local function parse(lyric)
  local lines = vim.iter(vim.split(lyric, "\n", { trimempty = true })):map(vim.trim):totable() ---@type string[]
  if #lines == 0 then
    return {}
  end

  local lyrics = {} ---@type lyricify.Lyric[]
  for _, line in ipairs(lines) do
    local timestamp, text = line:match([=[%[([%d%:%.]+)%]([^%[%]]*)]=])
    if timestamp and text then
      if text == "纯音乐, 请欣赏" then
        return {}
      end
      local min, sec = unpack(vim.iter(vim.split(timestamp, ":")):map(tonumber):totable())
      if min and sec then
        table.insert(lyrics, { start = (min * 60 + sec) * 1000, text = text })
      end
    end
  end

  table.sort(lyrics, function(lhs, rhs)
    return lhs.start < rhs.start
  end)

  return lyrics
end

---TODO: improve performance
---
---@param s string
---@return string
local function normalize(s)
  return vim.trim(
    Utils.t2s(
      s:gsub("（", "(")
        :gsub("）", ")")
        :gsub("【", "[")
        :gsub("】", "]")
        :gsub("。", ". ")
        :gsub("；", "; ")
        :gsub("：", ": ")
        :gsub("？", "? ")
        :gsub("！", "! ")
        :gsub("、，", ", ")
        :gsub("，", ", ")
        :gsub("‘", "'")
        :gsub("’", "'")
        :gsub("′", "'")
        :gsub("＇", "'")
        :gsub("“", '"')
        :gsub("”", '"')
        :gsub("〜", "~")
        :gsub("～", "~")
        :gsub("·", "•")
        :gsub("・", "•")
        :gsub("%s+", " ")
        :gsub("%s%-%s.*", "")
        :gsub("%(.+%)", "")
    )
  )
end

---@return boolean
function Base:retriable()
  return false
end

---@return lyricify.lyrics.Error
function Base:unreachable()
  return vim.deepcopy(Error.TEMPORARY_UNREACHABLE)
end

--- Do nothing.
---@param filename string
---@diagnostic disable-next-line: unused-local
function Base:save(filename) end

--- Do nothing.
---@param value? integer
---@return integer
---@diagnostic disable-next-line: unused-local
function Base:shift(value)
  return 0
end

---@param filename string
---@return lyricify.lyrics.Base
function Base:from(filename)
  if vim.fn.filereadable(filename) == 0 then
    return vim.deepcopy(Error.NONE)
  end
  local res = vim.json.decode(table.concat(vim.fn.readfile(filename), "\n"))
  return Result:new(res.original, res.translation, res.shift_time)
end

---@async
---@param metadata lyricify.Metadata
---@return lyricify.lyrics.Base
function Base:fetch(metadata)
  local keyword = ("%s %s"):format(normalize(metadata.title), metadata.artist)
  local url = ("http://music.163.com/api/search/get/?s=%s&limit=10&type=1&offset=0"):format(vim.uri_encode(keyword))

  Utils.debug("Keyword: `%s`, URL: `%s`", keyword, url)

  local res = Async.system({ "curl", "-fsSL", "-m", tostring(Config.network.timeout / 1000), url })
  if res.code ~= 0 then
    return self:unreachable()
  end

  local body = vim.json.decode(res.stdout)
  if body.code ~= 200 then
    return self:unreachable()
  end

  -- NOTE: artists' name can vary in different languages, which is hard to compare.
  local song = vim.iter(vim.json.decode(res.stdout).result.songs or {}):find(function(v)
    return vim.iter(vim.list_extend(vim.list_extend({ v.name }, v.alias or {}), v.transNames or {})):any(function(name)
      return normalize(name):upper() == normalize(metadata.title):upper()
    end) and math.abs(v.duration - metadata.duration) <= Config.diff_time
  end)
  if not song then
    return vim.deepcopy(Error.SONG_NOT_FOUND)
  end

  url = ("http://music.163.com/api/song/lyric?os=osx&id=%s&lv=-1&kv=-1&tv=-1"):format(song.id)

  Utils.debug("Lyrics found, URL is `%s`", url)

  res = Async.system({ "curl", "-fsSL", "-m", tostring(Config.network.timeout / 1000), url })
  if res.code ~= 0 then
    return self:unreachable()
  end

  body = vim.json.decode(res.stdout)
  if body.code ~= 200 then
    return self:unreachable()
  end

  if not body.lrc then
    return vim.deepcopy(Error.LYRICS_NOT_FOUND)
  end

  return Result:new(
    parse(body.lrc.lyric),
    body.tlyric and parse(body.tlyric.lyric) or {},
    type(Config.shift_time) == "function" and Config.shift_time(metadata.duration, song.duration) or Config.shift_time
  )
end

---@async
---@param metadata lyricify.Metadata
---@return lyricify.lyrics.Base
function Base:load(metadata)
  if Async.fn.isdirectory(Config.__cache_dir) == 0 then
    Async.fn.mkdir(Config.__cache_dir)
  end

  Async.schedule()
  local res = self:from(metadata:filename())

  if res:instance_of("lyrics.Error") then
    res = self:fetch(metadata)
    Async.schedule()
    res:save(metadata:filename())
  end

  return res
end

local current_metadata = nil ---@type lyricify.Metadata?
local current_lyrics = Error.NONE ---@type lyricify.lyrics.Base

---@class lyricify.lyrics
local M = {}

---@param all? boolean
function M.clear(all)
  if all then
    pcall(vim.fs.rm, Config.__cache_dir, { recursive = true })
  elseif current_metadata then
    vim.fs.rm(current_metadata:filename())
  end
  M.refresh()
end

---@param value? integer
---@return integer
function M.shift(value)
  return current_lyrics:shift(value)
end

function M.refresh()
  current_metadata = nil
  current_lyrics = vim.deepcopy(Error.NONE)
end

-- TODO: add file watch
return setmetatable(M, {
  ---@async
  ---@param metadata lyricify.Metadata
  ---@return lyricify.lyrics.Base
  __call = function(_, metadata)
    if current_lyrics:retriable() or not vim.deep_equal(metadata, current_metadata) then
      current_lyrics = current_lyrics:load(metadata)
      current_metadata = metadata
    end
    return current_lyrics
  end,
})
