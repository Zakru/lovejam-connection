local menuState = {}

local sendChannel, recvChannel
local jobs

function menuState.load()
  sendChannel = love.thread.getChannel "commSend"
  recvChannel = love.thread.getChannel "commRecv"
end

function menuState.enter()
  recvChannel:clear()
  sendChannel:push { "list" }
  jobs = {}
end

function menuState.update(dt)
  if recvChannel:getCount() > 0 then
    local what, response, err = unpack(recvChannel:pop())
    print(what, #response, err)
    if what == "list" then
      if response then
        jobs = response
      end
    end
  end
end

function menuState.draw()
  for i,job in ipairs(jobs) do
    love.graphics.print(job, 0, (i-1)*10)
  end
end

return menuState
