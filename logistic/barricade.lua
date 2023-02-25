local vecmath = require "vecmath"

local barricade = {}
local barricadeMeta = { __index = {} }

local barricadeImage

function barricade.load()
  barricadeImage = love.graphics.newImage("assets/barricade.png")
end

function barricade.new(world, init, ground)
  local b = init

  b.body = love.physics.newBody(world, b.x, b.y, "static")
  b.body:setAngle(b.r)
  love.physics.newFixture(b.body, love.physics.newRectangleShape(100, 480))

  return setmetatable(b, barricadeMeta)
end

function barricadeMeta.__index:draw()
  love.graphics.draw(barricadeImage, self.x, self.y, self.r, 1, 1, 64, 256)
end

return barricade
