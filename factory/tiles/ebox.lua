local commonAssets = require "commonAssets"

local ebox = {}
local eboxMeta = { __index = ebox }

function ebox.new(init)
  local eb = init or {}

  eb.kind = "ebox"
  eb.count = eb.count or 0

  return setmetatable(eb, eboxMeta)
end

function ebox.read(f, saveIds)
  local kindId, count = assert(love.data.unpack(">BI4", (assert(f:read(5)))))
  return {
    itemKind = kindId > 0 and saveIds.item[kindId] or nil,
    count = count,
  }
end

function ebox:write(data, saveIds)
  table.insert(data, love.data.pack("data", ">BI4", self.itemKind and saveIds.item[self.itemKind] or 0, self.count))
end

function ebox:draw()
  if self.itemKind then
    love.graphics.draw(commonAssets.items.atlas, self.itemKind.quad, 16, 16)
  end
end

return ebox
