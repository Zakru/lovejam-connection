local map = require "map"
local vecmath = require "vecmath"
local drawFuncs = require "drawFuncs"
local logisticClient = require "logisticClient"
local gameData = require "gameData"
local constants = require "constants"

local drivingState = {}
local drivingMeta = { __index = {} }

local car

function drivingState.load()
  car = love.graphics.newImage("assets/car.png")
end

function drivingState.new(job)
  local d = {}

  d.job = job
  d.world = love.physics.newWorld()
  love.physics.setMeter(64)

  d.ground = love.physics.newBody(d.world, 0, 0, "static")

  d.map = map.generate(d.world, job.amount * constants.CARGO_VALUE[job.cargo], d.ground)

  d.carBody = love.physics.newBody(d.world, 0, 0, "dynamic")
  love.physics.newFixture(d.carBody, love.physics.newRectangleShape(256, 128))

  d.steer = 0

  local friction = love.physics.newFrictionJoint(d.ground, d.carBody, 0, 0)
  friction:setMaxForce(128)
  friction:setMaxTorque(0)

  d.camx, d.camy = 0, 0
  d.startTime = 5
  d.time = 60
  d.health = 1

  d.weaponTimer = math.huge
  d.bullets = {}
  d.enemies = {}

  for _,ent in ipairs(d.map.entities) do
    if ent.damage and ent.body then
      d.enemies[ent.body] = ent
    end
  end

  return setmetatable(d, drivingMeta)
end

function drivingMeta.__index:update(dt)
  if self.startTime > 0 then
    self.startTime = self.startTime - dt
  elseif not self.endStatus then
    self:updateGame(dt)
  end
end

function drivingMeta.__index:updateGame(dt)
  local iend = #self.bullets
  local ihead = 1
  for i=1,iend do
    local bullet = self.bullets[i]
    bullet.time = bullet.time + dt

    self.bullets[i] = nil
    if bullet.time < 0.125 then
      self.bullets[ihead] = bullet
      ihead = ihead + 1
    end
  end

  local fireTime = 1 / math.sqrt(gameData.upgrades.weapon + 1)
  self.weaponTimer = self.weaponTimer + dt
  if self.weaponTimer > fireTime and love.mouse.isDown(1) then
    self.weaponTimer = 0
    local fromx, fromy = self.carBody:getWorldPoint(32, -32)
    local tw, th = love.graphics.getDimensions()
    local scale = (tw + th) / 2 / 1500
    local w, h = scale * tw, scale * th
    local targetx, targety = love.mouse.getPosition()
    targetx, targety = (targetx - tw/2) / scale - w/6 * -self.camx + self.carBody:getX(), (targety - th/2) / scale - h/6 * -self.camy + self.carBody:getY()
    local dx, dy = vecmath.scale(targetx - fromx, targety - fromy, 100000)
    local tox, toy
    self.world:rayCast(fromx, fromy, fromx + dx, fromy + dy, function(fixture, x, y, xn, yn, fraction)
      local body = fixture:getBody()
      if body == self.carBody then
        return -1
      end

      local enemy = self.enemies[body]
      if enemy then
        tox, toy = x, y
        enemy:damage(math.sqrt(gameData.upgrades.weapon + 1))
        return 0
      end

      return -1
    end)
    if not tox then
      tox, toy = 100000 * dx, 100000 * dy
    end
    table.insert(self.bullets, { sx = fromx, sy = fromy, ex = tox, ey = toy, time = 0 })
  end

  local forwardVel, sideVel = self.carBody:getLocalVector(self.carBody:getLinearVelocity())

  local accel = 0
  local steer = 0

  if love.keyboard.isDown("w") then
    accel = accel + 1
  end
  if love.keyboard.isDown("s") then
    accel = accel - 1
  end
  if love.keyboard.isDown("a") then
    steer = steer - 1
  end
  if love.keyboard.isDown("d") then
    steer = steer + 1
  end

  if self.steer < steer then
    self.steer = math.min(steer, self.steer + dt * 2)
  elseif self.steer > steer then
    self.steer = math.max(steer, self.steer - dt * 2)
  end

  local mass = self.carBody:getMass()
  local fx, fy = self.carBody:getLinearVelocityFromLocalPoint(96, 0)
  local rx, ry = self.carBody:getLinearVelocityFromLocalPoint(-64, 0)

  local maxFriction = 5000 * dt

  local fnx, fny = self.carBody:getWorldVector(math.sin(self.steer), -math.cos(self.steer))
  local ffx, ffy = vecmath.scale(fnx, fny, math.min(math.max(-vecmath.dot(fnx, fny, fx, fy), -maxFriction), maxFriction)) -- Front wheel side velocity clamped
  self.carBody:applyLinearImpulse(ffx * 0.25 * mass, ffy * 0.25 * mass, self.carBody:getWorldPoint(128, 0))

  local rnx, rny = self.carBody:getWorldVector(0, -1)
  local rfx, rfy = vecmath.scale(rnx, rny, math.min(math.max(-vecmath.dot(rnx, rny, rx, ry), -maxFriction), maxFriction)) -- Rear wheel side velocity clamped
  self.carBody:applyLinearImpulse(rfx * 0.25 * mass, rfy * 0.25 * mass, self.carBody:getWorldPoint(-128, 0))

  local fdx, fdy = self.carBody:getWorldVector(math.cos(self.steer), math.sin(self.steer))
  local accelAmount = (gameData.upgrades.engine) * 200 + 500
  local accelx, accely = vecmath.scale(fdx, fdy, accel * accelAmount) -- Accel
  self.carBody:applyForce(accelx, accely, self.carBody:getWorldPoint(128, 0))

  local gameContext = {
    player = self.carBody,
    shoot = function(sx, sy, dx, dy, damage)
      local tox, toy
      self.world:rayCast(sx, sy, sx + dx, sy + dy, function(fixture, x, y, xn, yn, fraction)
        local body = fixture:getBody()
        if body == self.carBody then
          tox, toy = x, y
          self.health = self.health - 0.1 * damage / (1 + gameData.upgrades.hull * 0.5)
          return 0
        end

        return -1
      end)
      if not tox then
        tox, toy = 100000 * dx, 100000 * dy
      end
      table.insert(self.bullets, { sx = sx, sy = sy, ex = tox, ey = toy, time = 0 })
    end,
  }
  for _,ent in ipairs(self.map.entities) do
    if ent.update then
      ent:update(dt, gameContext)
    end
  end

  self.world:update(dt)

  local forwardVel, sideVel = self.carBody:getLocalVector(self.carBody:getLinearVelocity())

  -- Camera logic
  local sigmoid = (1 / (1 + math.exp(-forwardVel/128 - 1))) * 2 - 1
  self.camx, self.camy = self.carBody:getWorldVector(sigmoid, 0)

  -- Handle end
  if self.map.endTrigger then
    for _,contact in ipairs(self.map.endTrigger:getContacts()) do
      local a, b = contact:getFixtures()
      if a:getBody() == self.carBody or b:getBody() == self.carBody then
        self.map.endTrigger:destroy()
        self.map.endTrigger = nil
        self:endJob("success", true)
      end
    end
  end

  self.time = self.time - dt
  if self.time <= 0 then
    self:endJob("timeout", false)
  end

  if self.health <= 0 then
    self:endJob("captured", false)
  end
end

local STATUS_TITLE = {
  success = "Success!",
  timeout = "Too late!",
  captured = "You were captured!",
}

function drivingMeta.__index:draw()
  -- Set transformation
  love.graphics.push()
  local tw, th = love.graphics.getDimensions()
  love.graphics.translate(tw/2, th/2) -- Center
  local scale = (tw + th) / 2 / 1500
  local w, h = scale * tw, scale * th
  love.graphics.scale(scale)
  love.graphics.translate(w/6 * -self.camx - self.carBody:getX(), h/6 * -self.camy - self.carBody:getY()) -- Camera

  -- Draw world
  self.map:draw()

  -- Draw car
  love.graphics.draw(car, self.carBody:getX(), self.carBody:getY(), self.carBody:getAngle(), 1, 1, 128, 64)

  -- Draw bullets
  for _,bullet in ipairs(self.bullets) do
    love.graphics.setColor(1, 1, 0, 1 - bullet.time * 8)
    love.graphics.line(bullet.sx, bullet.sy, bullet.ex, bullet.ey)
  end
  love.graphics.setColor(1,1,1,1)

  -- Pop transformation
  love.graphics.pop()

  w,h = tw, th
  -- Draw HUD
  if self.startTime > 0 then
    drawFuncs.printAligned(string.format("%d", math.ceil(self.startTime)), w/2, h/2-5)
  elseif self.endStatus then
    drawFuncs.printAligned(STATUS_TITLE[self.endStatus.status], w/2, h/2 - 50)
    love.graphics.print("Remaining time:", w/2 - 100, h/2 - 30)
    drawFuncs.printAligned(string.format("%.01f s", self.endStatus.timeRemaining), w/2 + 100, h/2 - 30, 1)
    if self.endStatus.reward then
      love.graphics.print("Reward earned:", w/2 - 100, h/2 - 10)
      drawFuncs.printAligned(string.format("+%d ¤", self.endStatus.reward), w/2 + 100, h/2 - 10, 1)
      love.graphics.print("Total money:", w/2 - 100, h/2 + 10)
      drawFuncs.printAligned(string.format("%d ¤", gameData.money), w/2 + 100, h/2 + 10, 1)
    end
    drawFuncs.printAligned("Press ENTER to return to the menu", w/2, h/2 + 64)
  else
    drawFuncs.printAligned(string.format("%.01f", self.time), w/2, 4)
    love.graphics.setColor(1,0,0,1)
    love.graphics.rectangle("fill", w/2 - 100, h-20, 200, 16)
    love.graphics.setColor(0,1,0,1)
    love.graphics.rectangle("fill", w/2 - 100, h-20, 200 * math.max(self.health, 0), 16)
  end
end

local function onUpdateJob(status, err)
  if not status then
    print("error while updating job: " .. err)
  end
end

function drivingMeta.__index:endJob(status, success)
  self.endStatus = {
    status = status,
    success = success,
    timeRemaining = math.max(self.time, 0),
  }

  if success then
    if self.job.id then
      logisticClient.completeJob(onUpdateJob)
    end
    local reward = self.job.amount * constants.CARGO_VALUE[self.job.cargo]
    self.endStatus.reward = reward
    gameData.addMoney(reward)
  else
    if self.job.id then
      logisticClient.failJob(onUpdateJob)
    end
  end
end

function drivingMeta.__index:keypressed(key, scancode, isRepeat)
  if (key == "return" or key == "enter") and self.endStatus then
    self.finish()
  end
end

return drivingState
