local drawFuncs = {}

function drawFuncs.printAligned(text, x, y, alignment)
  local w = love.graphics.getFont():getWidth(text)
  love.graphics.print(text, x, y, 0, 1, 1, w * (alignment or 0.5))
end

return drawFuncs
