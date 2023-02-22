local uiEvents = require "ui.uiEvents"
local vecmath = require "vecmath"

local leftBar = {}
local leftBarMeta = { __index = leftBar }

function leftBar.new(init)
  local l = init or { children={} }

  l.t = 0

  return setmetatable(l, leftBarMeta)
end

function leftBar:update(dt)
  self.t = vecmath.approach(self.t, self.open and 1 or 0, dt * 4)

  for _,c in pairs(self.children) do
    if c.update then
      c:update(dt)
    end
  end
end

function leftBar:draw()
  if self.t ~= 0 then
    love.graphics.push()
    local x = (self.open and 1 - (1 - self.t) * (1 - self.t) or self.t * self.t) - 1
    love.graphics.translate(x * 256, 0)

    love.graphics.setColor(0,0,0, 0.5)
    love.graphics.rectangle("fill", 0, 0, 256, love.graphics.getHeight())
    love.graphics.setColor(1,1,1,1)

    for _,c in pairs(self.children) do
      if c.draw then
        c:draw()
      end
    end
    love.graphics.pop()
  end
end

uiEvents.handle(leftBar, function(event) return function(self, x, y, ...)
  x = x - (self.open and 1 - (1 - self.t) * (1 - self.t) or self.t * self.t) * 256 + 256
  for i=#self.children,1,-1 do
    local c = self.children[i]
    local consumed = c[event] and c[event](c, x, y, ...)
    if consumed then
      return consumed
    end
  end
  return nil
end end)

return leftBar
