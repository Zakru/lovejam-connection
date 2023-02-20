local drivingState = require "drivingState"
local map = require "map"
local menuState = require "menuState"

local world
local commThread = nil
local state = "menu"

function love.load()
  map.load()
  drivingState.load()
  menuState.load()

  commThread = love.thread.newThread("commThread.lua")
  commThread:start("127.0.0.1", 5483)

  menuState.enter()
end

function love.update(dt)
  if state == "menu" then
    menuState.update(dt)
  elseif state == "driving" then
    world:update(dt)
  end
end

function love.draw()
  if state == "menu" then
    menuState.draw()
  elseif state == "driving" then
    world:draw()
  end
end

function menuState.startJob(job)
  world = drivingState.new(job)
  state = "driving"
end

function love.keypressed(key, scancode, isRepeat)
  if state == "menu" then
    menuState.keypressed(key, scancode, isRepeat)
  end
end
