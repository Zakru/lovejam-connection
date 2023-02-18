local drivingState = require "drivingState"
local map = require "map"
local menuState = require "menuState"

local world
local commThread = nil

function love.load()
  map.load()
  drivingState.load()
  menuState.load()

  commThread = love.thread.newThread("commThread.lua")
  commThread:start("127.0.0.1", 5483)

  world = drivingState.new()

  menuState.enter()
end

function love.update(dt)
  menuState.update(dt)
  --world:update(dt)
end

function love.draw()
  menuState.draw()
  --world:draw()
end
