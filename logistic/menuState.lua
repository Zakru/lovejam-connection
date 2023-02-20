local logisticClient = require "logisticClient"

local menuState = {}

local jobs
local listRequestTime
local state = "main"
local LIST_REQUEST_TIMEOUT = 2

local function onListJobs(newJobs, err)
  print("list", newJobs, err)
  if newJobs == nil then
    print("error while fetching jobs: " .. err)
    return
  end

  jobs = newJobs
end

local function onTakeJob(job)
  return function(status, err)
    print("take", status, err)
    if status == nil then
      print("error while taking job: " .. err)
      return
    elseif status == false then
      print("error trying to take job: " .. err)
      return
    end
    menuState.startJob {}
  end
end

function menuState.enter()
  listRequestTime = love.timer.getTime()
  jobs = nil
  logisticClient.listJobs(onListJobs)
end

local function genJob()
end

function menuState.update(dt)
  if jobs == nil and love.timer.getTime() < listRequestTime + LIST_REQUEST_TIMEOUT then
    jobs = {}
    for i=1,6 do
      jobs[i] = genJob()
    end
  end
end

local function jobAabb(i)
  local w, h = love.graphics.getDimensions()
  local c, r = (i - 1) % 3, (i - (i - 1) % 3) / 3
  return w/2 - 224 + c * 160, h/2 - 144 + c * 160, 128, 128
end

function menuState.draw()
  if state == "jobs" then
    for i,job in ipairs(jobs) do
      love.graphics.print(string.format("%f %s", job.amount, job.cargo), 0, (i-1)*10)
    end
  end
end

function menuState.keypressed(key, scancode, isRepeat)
  if key == "return" then
    if #jobs > 0 then
      logisticClient.takeJob(onTakeJob(jobs[1]), jobs[1].id)
    end
  elseif key == "j" then
    state = "jobs"
  end
end

return menuState
