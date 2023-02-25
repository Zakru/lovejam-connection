local drivingState = require "drivingState"
local map = require "map"
local menuState = require "menuState"
local logisticClient = require "logisticClient"
local gameData = require "gameData"
local enemy = require "enemy"
local barricade = require "barricade"

local world
local state = "menu"

function love.load()
  math.randomseed(os.time()); math.random(); math.random(); math.random()

  map.load()
  drivingState.load()
  enemy.load()
  barricade.load()

  logisticClient.connect("127.0.0.1", 5483)

  if love.filesystem.getInfo("save") then
    gameData.read()
  end

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
  world = nil
end

function menuState.startJob(job)
  world = drivingState.new(job)
  world.finish = onEndJob
  state = "driving"
end

function love.mousepressed(...)
  if state == "menu" then
    menuState.mousepressed(...)
  end
end

function love.mousemoved(...)
  if state == "menu" then
    menuState.mousemoved(...)
  end
end

function love.keypressed(key, scancode, isRepeat)
  if state == "menu" then
    --menuState.keypressed(key, scancode, isRepeat)
  elseif state == "driving" then
    world:keypressed(key, scancode, isRepeat)
  end
end

function love.quit()
  gameData.write()
end
