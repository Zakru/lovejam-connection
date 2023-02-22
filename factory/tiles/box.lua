local commonAssets = require "commonAssets"

local box = {}
local boxMeta = { __index = box }

function box.new(init)
  local b = init or {}

  b.kind = "box"

  return setmetatable(b, boxMeta)
end

function box:draw()
  if self.itemKind then
    love.graphics.draw(commonAssets.items.atlas, self.itemKind.quad, 16, 16)
  end
end

return box
