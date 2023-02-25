local commonAssets = require "commonAssets"

local box = {}
local boxMeta = { __index = box }

function box.new(init)
  local b = init or {}

  b.kind = "box"

  return setmetatable(b, boxMeta)
end

function box.read(f, saveIds)
  local kindId = assert(love.data.unpack(">B", (assert(f:read(1)))))
  return {
    itemKind = kindId > 0 and saveIds.item[kindId] or nil,
  }
end

function box:write(data, saveIds)
  table.insert(data, love.data.pack("data", ">B", self.itemKind and saveIds.item[self.itemKind] or 0))
end

function box:draw()
  if self.itemKind then
    love.graphics.draw(commonAssets.items.atlas, self.itemKind.quad, 16, 16)
  end
end

return box
