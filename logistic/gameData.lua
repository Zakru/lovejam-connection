local gameData = {}

gameData.money = 0
gameData.totalMoney = 0
gameData.upgrades = {
  engine = 0,
  weapon = 0,
  hull = 0,
}

local function readData(f, pattern)
  return assert(love.data.unpack(pattern, (assert(f:read(love.data.getPackedSize(pattern))))))
end

function gameData.addMoney(amount)
  gameData.money = gameData.money + amount
  gameData.totalMoney = gameData.totalMoney + amount
end

function gameData.write()

  local data = {}

  table.insert(data, love.data.pack("string", ">nnnnn",
    gameData.money,
    gameData.totalMoney,
    gameData.upgrades.engine,
    gameData.upgrades.weapon,
    gameData.upgrades.hull
  ))

  local f = assert(love.filesystem.newFile("save", "w"), "Failed to open save for writing")
  for _,d in ipairs(data) do
    f:write(d)
  end
end

function gameData.read()
  local f = assert(love.filesystem.newFile("save", "r"), "Failed to open save for reading")

  gameData.money,
    gameData.totalMoney,
    gameData.upgrades.engine,
    gameData.upgrades.weapon,
    gameData.upgrades.hull = readData(f, ">nnnnn")
end

return gameData
