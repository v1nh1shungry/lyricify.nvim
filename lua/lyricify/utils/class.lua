---@class lyricify.Object
---@field __name string
---@field __super? lyricify.Object
local Object = {}

Object.__name = "Object"

---@param name string
---@return boolean
function Object:instance_of(name)
  local class = self
  while class do
    if class.__name == name then
      return true
    end
    class = class.__super
  end
  return false
end

function Object:initialize(...) end

---@return any
function Object:new(...)
  local instance = setmetatable({}, { __index = self })
  instance:initialize(...)
  return instance
end

return setmetatable(Object, {
  ---@param name string
  ---@param super? lyricify.Object
  ---@return lyricify.Object
  __call = function(_, name, super)
    return setmetatable({
      __name = name,
      __super = super or Object,
    }, { __index = super or Object })
  end,
})
