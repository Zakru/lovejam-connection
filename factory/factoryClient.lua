local client = require "client"

local factoryClient = {}

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

factoryClient.postJob = wrapTask(function(cb, job, transfer)
  local success, err = client.send("post\0" .. love.data.pack("string", ">s1f", job.cargo, job.amount))
  if success == nil then
    factoryClient.disconnect()
    print(err)
    cb(nil, err, job, transfer)
    return
  end

  local packetType, dataErr = coroutine.yield "post"
  if not packetType then
    if packetType == nil then
      factoryClient.disconnect()
    end
    print(dataErr)
    cb(nil, dataErr, job, transfer)
    return
  end

  local id = love.data.unpack(">I4", dataErr)
  job.id = id
  cb(job, transfer)
end)

factoryClient.cancelJob = wrapTask(function(job)
  local success, err = client.send("cancel\0" .. love.data.pack("string", ">I4", job.id))
  if success == nil then
    factoryClient.disconnect()
    print(err)
    return
  end

  local packetType, dataErr = coroutine.yield "cancel"
  if not packetType then
    if packetType == nil then
      factoryClient.disconnect()
    end
    print(dataErr)
    return
  end
end)

factoryClient.connect = wrapTask(function(address, port)
  if client.connect(address, port, 1) then
    recvTask = coroutine.create(client.receive)
  else
    print "connection error"
  end
end)

function factoryClient.disconnect()
  client.disconnect()
  recvTask = nil
end

function factoryClient.update()
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

        if packetType == "taken" or packetType == "completed" then
          if factoryClient.jobUpdated then
            factoryClient.jobUpdated(packetType, love.data.unpack(">I4", dataErr))
          end
        end
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

return factoryClient
