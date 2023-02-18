local socket = require "socket"

local client = {}
local connection = nil

local sendAll = socket.protect(function(data)
  if connection ~= nil then
    local start = 1
    while start <= string.len(data) do
      start = socket.try(connection:send(data, start)) + 1
    end
    return true
  end

  return nil, "not connected"
end)

function client.connect(address, port, mode)
  connection = socket.tcp()
  if not connection:connect(address, port) then
    connection:close()
    connection = nil
    return false
  end

  sendAll("connectiongame\0001\0")

  if connection:receive(17) ~= "connectiongame\0001\0" then
    connection:close()
    connection = nil
    return false
  end

  sendAll(string.char(mode))
end

client.send = socket.protect(function(packet)
  local size = string.len(packet)
  if size >= 0 and size < 0x10000 then
    local sizeBytes = love.data.pack("string", ">I2", size)
    socket.try(sendAll(sizeBytes .. packet))
    return true
  else
    return nil, "packet too large"
  end
end)

client.receive = socket.protect(function()
  if connection ~= nil then
    local size = love.data.unpack(">I2", socket.try(connection:receive(2)))
    local packet = socket.try(connection:receive(size))
    if string.byte(packet) == 0xff then
      return false, string.sub(packet, 2)
    end
    local packetType, restStart = love.data.unpack("z", packet)
    print(packetType, packet, restStart)
    local rest = string.sub(packet, restStart)
    return packetType, rest
  end

  return nil, "not connected"
end)

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
