local commonAssets = require "commonAssets"
local vecmath = require "vecmath"

local applicator = {}
local applicatorMeta = { __index = applicator }

function applicator.new(init)
  local b = init or {}

  b.kind = "applicator"

  return setmetatable(b, applicatorMeta)
end

function applicator.read(f, saveIds)
  local kindId = assert(love.data.unpack(">B", (assert(f:read(1)))))
  return {
    itemKind = kindId > 0 and saveIds.item[kindId] or nil,
  }
end

function applicator:write(data, saveIds)
  table.insert(data, love.data.pack("data", ">B", self.itemKind and saveIds.item[self.itemKind] or 0))
end

function applicator:draw(tile, tickTime)
  if self.itemKind then
    local x,y = 0,0
    if self.animate then
      x,y = vecmath.scale(tile.dx, tile.dy, -64+tickTime*64)
    end
    love.graphics.draw(commonAssets.items.atlas, self.itemKind.quad, 16+x, 16+y)
  end
end

return applicator
