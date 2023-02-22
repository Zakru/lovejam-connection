local uiEvents = require "ui.uiEvents"

local colorContainer = {}
local colorContainerMeta = { __index = colorContainer }

function colorContainer.new(init)
  local l = init or { children={} }

  return setmetatable(l, colorContainerMeta)
end


function colorContainer:update(dt)
  for _,c in pairs(self.children) do
    if c.update then
      c:update(dt)
    end
  end
end

function colorContainer:draw()
  love.graphics.push()
  love.graphics.translate(self.x, self.y)

  if self.color then
    love.graphics.setColor(unpack(self.color))
    love.graphics.rectangle("fill", 0, 0, self.w, self.h)
    love.graphics.setColor(1,1,1,1)
  end

  for _,c in pairs(self.children) do
    if c.draw then
      c:draw()
    end
  end
  love.graphics.pop()
end

uiEvents.handle(colorContainer, function(event) return function(self, x, y, ...)
  x, y = x - self.x, y - self.y
  for i,c in pairs(self.children) do
    local consumed = c[event] and c[event](c, x, y, ...)
    if consumed then
      return consumed
    end
  end
  return nil
end end)

return colorContainer
