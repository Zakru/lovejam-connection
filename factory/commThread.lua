local client = require "client"
local logisticClient = require "logisticClient"

local addr, port = ...

local sendChannel = love.thread.getChannel "commSend"
local recvChannel = love.thread.getChannel "commRecv"

client.connect(addr, port, 1) -- Factory client

while client.connected() do
  local packet, data = unpack(sendChannel:demand())
  if packet == "post" then
    factoryClient.postJob(data)
  end
  local incoming = factoryClient.handleIncoming()
  if incoming ~= nil then
    recvChannel:push(incoming)
  end
end
