local uiDrawable = {}
local uiDrawableMeta = { __index = uiDrawable }

function uiDrawable.new(init)
  local b = init or {}

  return setmetatable(b, uiDrawableMeta)
end

function uiDrawable:draw()
  if not self.quad then
    love.graphics.draw(self.drawable, self.x, self.y, self.r, self.sx, self.sy, self.ox, self.oy)
  else
    love.graphics.draw(self.drawable, self.quad, self.x, self.y, self.r, self.sx, self.sy, self.ox, self.oy)
  end
end

return uiDrawable
