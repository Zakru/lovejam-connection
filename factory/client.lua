local socket = require "socket"

local client = {}
local connection = nil
local peeked = nil

local function sendAll(data)
  if connection == nil then
    return nil, "not connected"
  end

  local start = 1
  while start <= string.len(data) do
    local lastSent, err, lastSentErr = connection:send(data, start)
    if lastSent == nil then
      if err ~= "timeout" then
        return nil, err
      end
      start = lastSentErr + 1
      coroutine.yield()
    else
      start = lastSent + 1
    end
  end
  return true
end

local function receiveExact(size)
  if connection == nil then
    return nil, "not connected"
  end

  local parts = {}
  local remaining = size
  while remaining > 0 do
    local received, err, partial = connection:receive(remaining)
    if received == nil then
      if err ~= "timeout" then
        return nil, err
      end
      parts[#parts+1] = partial
      remaining = remaining - string.len(partial)
      coroutine.yield()
    else
      parts[#parts+1] = received
      remaining = remaining - string.len(received)
    end
  end

  return table.concat(parts)
end

function client.connect(address, port, mode)
  if connection ~= nil then
    return nil, "already connected"
  end

  connection = socket.tcp()
  connection:settimeout(0)

  local result, err = connection:connect(address, port)
  if result == nil then
    if err == "timeout" then
      repeat
        coroutine.yield()
        local selectErr = socket.skip(2, socket.select(nil, { connection }, 0))
        if selectErr ~= nil and selectErr ~= "timeout" then
          client.disconnect()
          print("error while connecting: " .. selectErr)
          return false
        end
      until selectErr == nil
    else
      client.disconnect()
      print("error while connecting: " .. selectErr)
      return false
    end
  end

  if not sendAll("connectiongame\0001\0") then
    client.disconnect()
    print "failed to send magic packet"
    return false
  end

  if receiveExact(17) ~= "connectiongame\0001\0" then
    client.disconnect()
    print "did not receive magic packet"
    return false
  end

  if not sendAll(string.char(mode)) then
    client.disconnect()
    print "failed to send mode"
    return false
  end

  return true
end

function client.send(packet)
  if connection == nil then
    return nil, "not connected"
  end

  local size = string.len(packet)
  if size >= 0 and size < 0x10000 then
    local sizeBytes = love.data.pack("string", ">I2", size)
    local status, err = sendAll(sizeBytes .. packet)
    if status then
      return true
    else
      return status, err
    end
  else
    return nil, "packet too large"
  end
end

function client.receive()
  if connection == nil then
    return nil, "not connected"
  end

  local size = love.data.unpack(">I2", socket.try(receiveExact(2)))
  local packet, err = receiveExact(size)
  if packet == nil then
    return nil, err
  end

  if string.byte(packet) == 0xff then
    return false, string.sub(packet, 2)
  end
  local packetType, restStart = love.data.unpack("z", packet)
  local rest = string.sub(packet, restStart)
  return packetType, rest
end

function client.connected()
  return connection ~= nil
end

function client.disconnect()
  if connection ~= nil then
    connection:close()
    connection = nil
  end
end

return client
