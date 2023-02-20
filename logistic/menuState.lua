local menuState = {}

local sendChannel, recvChannel
local jobs
local listRequestTime
local state = "main"
local LIST_REQUEST_TIMEOUT = 2

function menuState.load()
  sendChannel = love.thread.getChannel "commSend"
  recvChannel = love.thread.getChannel "commRecv"
end

function menuState.enter()
  recvChannel:clear()
  sendChannel:push { "list" }
  listRequestTime = love.timer.getTime()
  jobs = nil
end

local function genJob()
end

function menuState.update(dt)
  if recvChannel:getCount() > 0 then
    local what, response, err = unpack(recvChannel:pop())

    if what == "list" then
      if response then
        jobs = response
      end
    end
  end

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
    for i=1,6 do
      local job = jobs[i]
    end
  end
end

function menuState.keypressed(key, scancode, isRepeat)
  if key == "return" then
    menuState.startJob {}
  elseif key == "j" then
    state = "jobs"
  end
end

return menuState
