local vecmath = require "vecmath"

local enemy = {}
local enemyMeta = { __index = {} }

-- Barrel = (62, 44) = +46, 12
-- CoM = (16, 0)
local enemyImage

function enemy.load()
  enemyImage = love.graphics.newImage("assets/enemy.png")
end

function enemy.new(world, init, ground, diffMul)
  local e = init

  e.body = love.physics.newBody(world, e.x, e.y, "dynamic")
  love.physics.newFixture(e.body, love.physics.newCircleShape(32))
  local friction = love.physics.newFrictionJoint(e.body, ground, 0, 0)
  friction:setMaxForce(1000)
  friction:setMaxTorque(1000)

  e.health = (2 + math.random() * 2) * diffMul
  e.damageMul = diffMul

  return setmetatable(e, enemyMeta)
end

function enemyMeta.__index:update(dt, gameContext)
  if self.health > 0 then
    local px, py = gameContext.player:getPosition()
    local selfx, selfy = self.body:getPosition()
    self.body:setAngle(math.atan2(py-selfy, px-selfx))

    if not self.shootTimer and vecmath.length(px-selfx, py-selfy) < 1000 then
      self.shootTimer = 0
    end

    if self.shootTimer then
      if vecmath.length(px-selfx, py-selfy) > 4000 then
        self.shootTimer = nil
      else
        self.shootTimer = self.shootTimer + dt
        if self.shootTimer >= 1.4 then
          self.shootTimer = 0
          self:shootAtPoint(gameContext, px, py)
        end
      end
    end
  end
end

function enemyMeta.__index:draw()
  local x,y = self.body:getPosition()
  if self.health <= 0 then
    love.graphics.setColor(0.5,0.5,0.5,1)
  end
  love.graphics.draw(enemyImage, x, y, self.body:getAngle(), 1, 1, 16, 32)
  love.graphics.setColor(1,1,1,1)
end

function enemyMeta.__index:damage(damage)
  self.health = self.health - damage
  if self.health <= 0 then
    for _,f in ipairs(self.body:getFixtures()) do
      f:destroy()
    end
  end
end

function enemyMeta.__index:shootAtPoint(gameContext, x, y)
  local selfx, selfy = self.body:getPosition()
  self.body:setAngle(math.atan2(y-selfy, x-selfx))
  local sx, sy = self.body:getWorldPoint(46, 12)
  local a = math.atan2(y-sy, x-sx) + math.random() * 0.2 - 0.1
  gameContext.shoot(sx, sy, math.cos(a) * 10000, math.sin(a) * 10000, self.damageMul)
end

return enemy
