local drivingState = require "drivingState"
local map = require "map"
local menuState = require "menuState"
local logisticClient = require "logisticClient"

local world
local state = "menu"

function love.load()
  math.randomseed(os.time()); math.random(); math.random(); math.random()

  map.load()
  drivingState.load()

  logisticClient.connect("127.0.0.1", 5483)

  menuState.enter()
end

function love.update(dt)
  logisticClient.update()

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

local function onEndJob()
  state = "menu"
  menuState.enter()
end

function menuState.startJob(job)
  world = drivingState.new(job)
  world.finish = onEndJob
  state = "driving"
end

function love.keypressed(key, scancode, isRepeat)
  if state == "menu" then
    menuState.keypressed(key, scancode, isRepeat)
  end
end
