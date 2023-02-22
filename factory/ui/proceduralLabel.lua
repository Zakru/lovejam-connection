local proceduralLabel = {}
local proceduralLabelMeta = { __index = proceduralLabel }

function proceduralLabel.new(init)
  local b = init or {}

  return setmetatable(b, proceduralLabelMeta)
end

function proceduralLabel:draw()
  if self.color then
    love.graphics.setColor(unpack(self.color))
  end
  love.graphics.print(self:getText(), self.x, self.y, self.r, self.sx, self.sy, self.ox, self.oy)
  love.graphics.setColor(1,1,1,1)
end

return proceduralLabel
