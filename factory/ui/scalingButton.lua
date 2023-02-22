local uiEvents = require "ui.uiEvents"
local vecmath = require "vecmath"

local scalingButton = {}
local scalingButtonMeta = { __index = scalingButton }

function scalingButton.new(init)
  local b = init or {}

  b.hovering = false
  b.clicking = false
  b.scale=0.85

  return setmetatable(b, scalingButtonMeta)
end

function scalingButton:update(dt)
  local targetScale = (self.hovering and not (self.clicking)) and 1 or 0.85
  self.scale = vecmath.expApproach(self.scale, targetScale, dt, 16)
end

function scalingButton:draw()
  if type(self.label) == "userdata" and self.label:typeOf("Drawable") then
    if not self.quad then
      local w, h = self.label:getDimensions()
      love.graphics.draw(self.label, self.x + self.w/2, self.y + self.h/2, 0, self.scale, self.scale, w/2, h/2)
    else
      love.graphics.draw(self.label, self.quad, self.x + self.w/2, self.y + self.h/2, 0, self.scale, self.scale, self.w/2, self.h/2)
    end
  end
end

function scalingButton:mousepressed(x,y, b, t, p)
  if uiEvents.mouseOverlaps(self.x, self.y, self.w, self.h, x, y) then
    self.clicking = true
    return self
  end

  return false
end

function scalingButton:mousereleased(x,y, b, t, p)
  if uiEvents.mouseOverlaps(self.x, self.y, self.w, self.h, x, y) then
    self.clicking = false
    return self
  end

  return false
end

function scalingButton:mousemoved(x,y, dx,dy, t)
  if uiEvents.mouseOverlaps(self.x, self.y, self.w, self.h, x, y) then
    return self
  end

  return false
end

function scalingButton:mouseclicked(x,y, b, t, p)
  self:cb()
end

function scalingButton:mouseentered(x,y, dx,dy, t)
  self.hovering = true
end

function scalingButton:mouseexited(x,y, dx,dy, t)
  self.hovering = false
end

return scalingButton
