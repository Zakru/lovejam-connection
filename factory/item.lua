local item = {}
local itemMeta = { __index = {} }

function item.new()
  local i = {}

  i.x = 0
  i.y = 0
  i.px = 0
  i.py = 0
  i.kind = "materials"
  i.id = "ore"
  i.alive = false

  return setmetatable(i, itemMeta)
end

function itemMeta.__index:spawn()
  self.px = self.x
  self.py = self.y
  self.alive = true
end

function itemMeta.__index:despawn()
  self.alive = false
end

return item
