local logisticClient = require "logisticClient"
local constants = require "constants"
local gameData = require "gameData"
local drawFuncs = require "drawFuncs"

local menuState = {}

local jobs
local listRequestTime
local state = "main"
local LIST_REQUEST_TIMEOUT = 2
local hoveringJob
local hoveringUpgrade
local hoveringTab

local TABS = {
  "jobs",
  "upgrades",
}

local TAB_TITLE = {
  jobs = "Jobs",
  upgrades = "Upgrades",
}

local function genJob(maxValue)
  local r = math.random() % 1 -- Eliminate the theoretical 1 that math.random() might produce
  local cargo = constants.CARGO_TYPES[math.floor(math.pow(r, 1.2) * #constants.CARGO_TYPES) + 1]
  local targetValue = (math.random() * 0.5 + 0.5) * maxValue
  return {
    cargo = cargo,
    amount = math.ceil(targetValue / constants.CARGO_VALUE[cargo]),
  }
end

local function fillJobs()
  local maxValue
  if #jobs > 0 then
    maxValue = 100000
    for _,job in ipairs(jobs) do
      maxValue = math.min(job.amount * constants.CARGO_VALUE[job.cargo], maxValue)
    end
    maxValue = maxValue * 0.8
  else
    maxValue = math.min(math.max(gameData.totalMoney * 0.2, 500), 100000)
  end
  print("max value: " .. tostring(maxValue))
  for i=#jobs+1,6 do
    jobs[i] = genJob(maxValue)
  end
end

local function onListJobs(newJobs, err)
  if newJobs == nil then
    print("error while fetching jobs: " .. err)
    return
  end

  jobs = newJobs
  fillJobs()
end

local function onTakeJob(job)
  return function(status, err)
    if status == nil then
      print("error while taking job: " .. err)
      return
    elseif status == false then
      print("error trying to take job: " .. err)
      listRequestTime = love.timer.getTime()
      jobs = nil
      logisticClient.listJobs(onListJobs)
      return
    end
    menuState.startJob(job)
  end
end

local function screenToMenuCoords(x, y)
  local w,h = love.graphics.getDimensions()
  return x - w/2, y - h/2
end

function menuState.enter()
  listRequestTime = love.timer.getTime()
  jobs = nil
  logisticClient.listJobs(onListJobs)
end

function menuState.update(dt)
  if jobs == nil and love.timer.getTime() > listRequestTime + LIST_REQUEST_TIMEOUT then
    jobs = {}
    fillJobs()
  end
end

local function tabAabb(i)
  return -116 + (i-1) * 132, -180, 100, 64
end

local function jobAabb(i)
  local c, r = (i - 1) % 3, (i - 1 - (i - 1) % 3) / 3
  return -272 + c * 192, -80 + r * 96, 160, 64
end

local function upgradeAabb(i)
  return -272 + (i-1) * 192, -32, 160, 64
end

local function upgradeCost(upgrades)
  return 500 + upgrades * 1000
end

function menuState.draw()
  local w,h = love.graphics.getDimensions()
  love.graphics.push()
  love.graphics.translate(w/2, h/2)

  if state == "jobs" then
    if jobs then
      for i,job in ipairs(jobs) do
        local jx, jy, jw, jh = jobAabb(i)
        love.graphics.push()
        love.graphics.translate(jx, jy)

        if job == hoveringJob then
          love.graphics.setColor(0.5,0.5,0.5,0.5)
        else
          love.graphics.setColor(0.5,0.5,0.5,0.25)
        end
        love.graphics.rectangle("fill", 0, 0, jw, jh)
        love.graphics.setColor(1,1,1,1)

        local jobText = string.format("%d %s\nReward:  %d ¤", job.amount, constants.CARGO_NAME[job.cargo], job.amount * constants.CARGO_VALUE[job.cargo])
        if job.id then
          jobText = jobText .. "\nHuman client"
        end
        love.graphics.printf(jobText, 0, 0, jw)
        love.graphics.pop()
      end
    end
    drawFuncs.printAligned(string.format("Balance: %d ¤", gameData.money), 0, 112)
  elseif state == "upgrades" then
    for i,upgrade in ipairs(constants.UPGRADES) do
      local ux, uy, uw, uh = upgradeAabb(i)
      love.graphics.push()
      love.graphics.translate(ux, uy)

      if upgrade == hoveringUpgrade then
        love.graphics.setColor(0.5,0.5,0.5,0.5)
      else
        love.graphics.setColor(0.5,0.5,0.5,0.25)
      end
      love.graphics.rectangle("fill", 0, 0, uw, uh)
      love.graphics.setColor(1,1,1,1)

      local upgradeText = string.format("%s: %d\nCost:  %d ¤\n%s", constants.UPGRADE_NAME[upgrade], gameData.upgrades[upgrade], upgradeCost(gameData.upgrades[upgrade]), constants.UPGRADE_DESC[upgrade])
      love.graphics.printf(upgradeText, 0, 0, uw)
      love.graphics.pop()
    end
    drawFuncs.printAligned(string.format("Balance: %d ¤", gameData.money), 0, 112)
  end

  for i,tab in ipairs(TABS) do
    local x, y, w, h = tabAabb(i)
    love.graphics.push()
    love.graphics.translate(x, y)

    if tab == hoveringTab then
      love.graphics.setColor(0.5,0.5,0.5,0.5)
    else
      love.graphics.setColor(0.5,0.5,0.5,0.25)
    end
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1,1,1,1)

    love.graphics.printf(TAB_TITLE[tab], 0, 25, w, "center")
    love.graphics.pop()
  end
  love.graphics.pop()
end

local function aabbContains(px, py, x, y, w, h)
  return px >= x and px < x+w and py >= y and py < y+h
end

function menuState.mousepressed(x,y, b, t, p)
  local w, h = love.graphics.getDimensions()
  local uix, uiy = x - w/2, y - h/2
  if state == "jobs" then
    if b == 1 then
      if jobs then
        for i,job in ipairs(jobs) do
          if aabbContains(uix, uiy, jobAabb(i)) then
            if job.id then
              logisticClient.takeJob(onTakeJob(job), job.id)
            else
              menuState.startJob(job)
            end
            return true
          end
        end
      end
    end
  elseif state == "upgrades" then
    if b == 1 then
      for i,upgrade in ipairs(constants.UPGRADES) do
        if aabbContains(uix, uiy, upgradeAabb(i)) then
          local cost = upgradeCost(gameData.upgrades[upgrade])
          if gameData.money >= cost then
            gameData.money = gameData.money - cost
            gameData.upgrades[upgrade] = gameData.upgrades[upgrade] + 1
          end
          return true
        end
      end
    end
  end

  if b == 1 then
    for i,tab in ipairs(TABS) do
      if aabbContains(uix, uiy, tabAabb(i)) then
        state = tab
        return true
      end
    end
  end
end

function menuState.mousemoved(x,y, dx, dy, t)
  hoveringJob = nil
  hoveringUpgrade = nil
  hoveringTab = nil
  local w, h = love.graphics.getDimensions()
  local uix, uiy = x - w/2, y - h/2
  if state == "jobs" then
    if jobs then
      for i,job in ipairs(jobs) do
        if aabbContains(uix, uiy, jobAabb(i)) then
          hoveringJob = job
          return true
        end
      end
    end
  elseif state == "upgrades" then
    for i,upgrade in ipairs(constants.UPGRADES) do
      if aabbContains(uix, uiy, upgradeAabb(i)) then
        hoveringUpgrade = upgrade
        return true
      end
    end
  end

  for i,tab in ipairs(TABS) do
    if aabbContains(uix, uiy, tabAabb(i)) then
      hoveringTab = tab
      return true
    end
  end

  return false
end

return menuState
