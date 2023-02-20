local client = require "client"

local logisticClient = {}

local taskQueue, taskWaiting, taskHead, recvTask
local function wrapTask(func)
  return function(...)
    local coro = coroutine.create(func)
    local task
    if taskQueue == nil then
      local status, arg = coroutine.resume(coro, ...)
      if status then
        if coroutine.status(coro) ~= "dead" then
          task = { coro=coro, waiting=arg }
        end
      else
        error("error while starting task: " .. arg)
      end
      taskQueue = task
    else
      task = { coro=coro, args={...} }
      taskHead.next = task
    end
    taskHead = task
  end
end

logisticClient.listJobs = wrapTask(function(cb)
  local success, err = client.send "list"
  if success == nil then
    client.disconnect()
    print(err)
    cb(nil, err)
    return
  end

  local packetType, dataErr = coroutine.yield "list"
  if not packetType then
    if packetType == nil then
      client.disconnect()
    end
    print(dataErr)
    cb(nil, dataErr)
    return
  end

  local ids = {}
  local start = 2
  for i=1,love.data.unpack("B", dataErr) do
    local id, cargo, amount, newStart = love.data.unpack(">I4s1f", dataErr, start)
    start = newStart
    ids[#ids+1] = { id=id, cargo=cargo, amount=amount }
  end

  cb(ids)
end)

logisticClient.takeJob = wrapTask(function(cb, id)
  local success, err = client.send(love.data.pack("string", ">zI4", "take", id))
  if success == nil then
    client.disconnect()
    print(err)
    cb(nil, err)
    return
  end

  local packetType, dataErr = coroutine.yield "take"
  if not packetType then
    print(dataErr)
    if packetType == nil then
      client.disconnect()
      return nil, dataErr
    end
    cb(false, dataErr)
    return
  end

  if love.data.unpack(">I4", dataErr) ~= id then
    client.disconnect()
    cb(nil, "invalid response")
    return
  end

  cb(true)
  return
end)

logisticClient.cargoValues = {
  scrap = 1,
  ore = 2,
}

logisticClient.cargoList = {
  "scrap",
  "ore",
}

logisticClient.connect = wrapTask(function(address, port)
  if client.connect(address, port, 2) then
    recvTask = coroutine.create(client.receive)
  else
    print "connection error"
  end
end)

function logisticClient.update()
  local status, arg, arg2
  if recvTask ~= nil then
    status, arg, arg2 = coroutine.resume(recvTask)
    if status then
      if coroutine.status(recvTask) == "dead" then
        local packetType, packet = arg, arg2
        if packetType == false then
          print("client error: " .. packet)
        end
        recvTask = coroutine.create(client.receive)
      end
    else
      error("error while receiving: " .. arg)
    end
  end

  while taskQueue ~= nil do
    if taskQueue.args then
      status, arg = coroutine.resume(taskQueue.coro, unpack(taskQueue.args))
      taskQueue.args = nil
    elseif taskQueue.waiting == nil or status and (arg == false or taskQueue.waiting == arg) then
      status, arg = coroutine.resume(taskQueue.coro, taskQueue.waiting and arg, taskQueue.waiting and arg2)
    else
      break
    end

    if status then
      if coroutine.status(taskQueue.coro) == "dead" then
        if taskQueue == taskHead then
          taskHead = nil
        end
        taskQueue = taskQueue.next
      else
        taskQueue.waiting = arg
        break
      end
    else
      error("error during a task: " .. arg)
    end
  end
end

return logisticClient
