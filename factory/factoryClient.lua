local client = require "client"

local factoryClient = {}

function factoryClient.postJob(job)
  local success, err = client.send(love.data.pack("string", ">s1f", job.cargo, job.amount))
  if success == nil then
    client.disconnect()
    print(err)
    return nil, err
  end

  return ids
end

function logisticClient.takeJob(id)
  local success, err = client.send(love.data.pack("string", ">zI4", "take", id))
  if success == nil then
    client.disconnect()
    print(err)
    return nil, err
  end

  local packetType, dataErr = client.receive()
  if not packetType then
    print(dataErr)
    if packetType == nil then
      client.disconnect()
      return nil, dataErr
    end
    return false, dataErr
  end

  if packetType ~= "take" or love.data.unpack(">I4", dataErr) ~= id then
    client.disconnect()
    return nil, "invalid response"
  end

  return true
end

function factoryClient.handleIncoming(id)
  local incoming, err = client.hasIncoming()

  if incoming == nil then
    client.disconnect()
    print(err)
    return nil, err
  end

  local packetType, dataErr = client.receive()
  if not packetType then
    print(dataErr)
    if packetType == nil then
      client.disconnect()
      return nil, dataErr
    end
    return false, dataErr
  end

  if packetType == "post" then
    local id = love.data.unpack(">I4", dataErr)
    return { "post", id }
  elseif packetType == "taken" then
    local id = love.data.unpack(">I4", dataErr)
    return { "taken", id }
  elseif packetType == "completed" then
    local id = love.data.unpack(">I4", dataErr)
    return { "completed", id }
  end

  return nil, "unknown packet"
end

return factoryClient
