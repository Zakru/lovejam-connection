local uiEvents = require "ui.uiEvents"

local layer = {}
local layerMeta = { __index = layer }

function layer.new(init)
  local l = init or { children={} }

  return setmetatable(l, layerMeta)
end

function layer:update(dt)
  for _,c in ipairs(self.children) do
    if c.update then
      c:update(dt)
    end
  end
end

function layer:draw()
  for _,c in ipairs(self.children) do
    if c.draw then
      c:draw()
    end
  end
end

uiEvents.handle(layer, function(event) return function(self, ...)
  for i=#self.children,1,-1 do
    local c = self.children[i]
    local consumed = c[event] and c[event](c, ...)
    if consumed then
      return consumed
    end
  end
  return nil
end end)

return layer
