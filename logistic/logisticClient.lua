local client = require "client"

local logisticClient = {}

function logisticClient.listJobs()
  local success, err = client.send "list"
  if success == nil then
    client.disconnect()
    print(err)
    return nil, err
  end

  local packetType, dataErr = client.receive()
  if not packetType then
    if packetType == nil then
      client.disconnect()
    end
    print(dataErr)
    return nil, dataErr
  end

  if packetType ~= "list" then
    client.disconnect()
    return nil, "invalid response"
  end

  local ids = {}
  local start = 2
  for i=1,love.data.unpack("B", dataErr) do
    local id, dir, cargo, amount, newStart = love.data.unpack(">I4BBf", dataErr, start)
    start = newStart
    ids[#ids+1] = { id=id, direction=dir, cargo=cargo, amount=amount }
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

return logisticClient
