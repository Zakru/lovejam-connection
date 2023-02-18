local client = require "client"
local logisticClient = require "logisticClient"

local addr, port = ...

local sendChannel = love.thread.getChannel "commSend"
local recvChannel = love.thread.getChannel "commRecv"

client.connect(addr, port, 2) -- Logistic client

while client.connected() do
  local packet, data = unpack(sendChannel:demand())
  if packet == "list" then
    recvChannel:push {"list", logisticClient.listJobs()}
  elseif packet == "take" then
    recvChannel:push {"take", logisticClient.takeJob(data)}
  end
end
