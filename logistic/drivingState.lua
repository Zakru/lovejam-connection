local map = require "map"
local vecmath = require "vecmath"

local drivingState = {}
local drivingMeta = { __index = {} }

local car

function drivingState.load()
  car = love.graphics.newImage("assets/car.png")
end

function drivingState.new()
  local d = {}

  d.map = map.generate()
  love.physics.setMeter(64)
  d.world = love.physics.newWorld()

  d.ground = love.physics.newBody(d.world, 0, 0, "static")

  d.carBody = love.physics.newBody(d.world, 0, 0, "dynamic")
  love.physics.newFixture(d.carBody, love.physics.newRectangleShape(256, 128))

  d.steer = 0

  local friction = love.physics.newFrictionJoint(d.ground, d.carBody, 0, 0)
  friction:setMaxForce(128)
  friction:setMaxTorque(0)

  d.camx, d.camy = 0, 0

  return setmetatable(d, drivingMeta)
end

function drivingMeta.__index:update(dt)
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
  local accelx, accely = vecmath.scale(fdx, fdy, accel * 2000) -- Accel
  self.carBody:applyForce(accelx, accely, self.carBody:getWorldPoint(128, 0))

  self.world:update(dt)

  local forwardVel, sideVel = self.carBody:getLocalVector(self.carBody:getLinearVelocity())

  -- Camera logic
  local sigmoid = (1 / (1 + math.exp(-forwardVel/128 - 1))) * 2 - 1
  self.camx, self.camy = self.carBody:getWorldVector(sigmoid, 0)
end

function drivingMeta.__index:draw()
  -- Set transformation
  love.graphics.push()
  local w, h = love.graphics.getDimensions()
  love.graphics.translate(w/2, h/2) -- Center
  love.graphics.translate(w/6 * -self.camx - self.carBody:getX(), h/6 * -self.camy - self.carBody:getY()) -- Camera

  -- Draw world
  self.map:draw()

  -- Draw car
  love.graphics.draw(car, self.carBody:getX(), self.carBody:getY(), self.carBody:getAngle(), 1, 1, 128, 64)

  -- Pop transformation
  love.graphics.pop()
end

return drivingState