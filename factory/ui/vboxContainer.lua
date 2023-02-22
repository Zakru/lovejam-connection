local uiEvents = require "ui.uiEvents"

local vboxContainer = {}
local vboxContainerMeta = { __index = vboxContainer }

function vboxContainer.new(init)
  local l = init or { children={} }

  return setmetatable(l, vboxContainerMeta)
end

function vboxContainer:update(dt)
  for _,c in ipairs(self.children) do
    if c.update then
      c:update(dt)
    end
  end
end

function vboxContainer:draw()
  love.graphics.push()
  love.graphics.translate(self.x, self.y)

  for _,c in ipairs(self.children) do
    if c.draw then
      c:draw()
    end
    love.graphics.translate(0, self.separation)
  end
  love.graphics.pop()
end

function vboxContainer:add(element)
  table.insert(self.children, element)
end

function vboxContainer:remove(element)
  for i,e in ipairs(self.children) do
    if e == element then
      table.remove(self.children, i)
    end
  end
end

uiEvents.handle(vboxContainer, function(event) return function(self, x, y, ...)
  x, y = x - self.x, y - self.y - #self.children * self.separation
  for i=#self.children,1,-1 do
    y = y + self.separation
    local c = self.children[i]
    local consumed = c[event] and c[event](c, x, y, ...)
    if consumed then
      return consumed
    end
  end
  return nil
end end)

return vboxContainer
