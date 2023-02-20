local tilemap = {}
local tilemapMeta = { __index = {} }

function tilemap.new(texture, w, h, tileSize, tile)
  local m = {}

  m.w, m.h = w, h
  m.map = {}
  m.batch = love.graphics.newSpriteBatch(texture, w*h, "dynamic")
  m.tileSize = tileSize
  m.tileCount = 0
  m.activeTiles = {}

  setmetatable(m, tilemapMeta)

  for i=1,w*h do
    m.batch:add(0, 0, 0, 0, 0)
  end

  if tile ~= nil then
    m:fill(tile)
  end

  return m
end

function tilemapMeta.__index:fill(tile)
  for y=0,self.h-1 do
    for x=0,self.w-1 do
      local i = self.w * y + x + 1
      self.map[i] = tile
      self.batch:set(i, tile, x * self.tileSize, y * self.tileSize)
    end
  end
  self.tileCount = self.w * self.h
end

function tilemapMeta.__index:getTile(x, y)
  local i = self:index(x, y)
  if i then
    return self.map[self.w * y + x + 1]
  else
    return nil
  end
end

function tilemapMeta.__index:setTile(x, y, tile)
  local i = self:index(x, y)
  if not i then
    return false
  end

  local prevTile = self.map[i]
  self.map[i] = tile
  self.activeTiles[i] = tile and tile.activeTile and tile.activeTile.new()
  if tile == nil then
    self.batch:set(i, 0, 0, 0, 0, 0)
    if prevTile ~= nil then
      self.tileCount = self.tileCount - 1
    end
  else
    self.batch:set(i, tile.quad, (x + 0.5) * self.tileSize, (y + 0.5) * self.tileSize, tile.r or 0, 1, 1, 0.5 * self.tileSize, 0.5 * self.tileSize)
    if prevTile == nil then
      self.tileCount = self.tileCount + 1
    end
  end

  return true
end

function tilemapMeta.__index:draw()
  love.graphics.draw(self.batch, x, y)
end

function tilemapMeta.__index:index(x, y)
  if x < 0 or y < 0 or x >= self.w or y >= self.h then
    return nil
  end

  return self.w * y + x + 1
end

function tilemapMeta.__index:iterActiveTiles()
  local inner, s, var = pairs(self.activeTiles)
  return function()
    local i, activeTile = inner(s, var)
    var = i
    if i == nil then return nil end

    return (i - 1) % self.w, (i - 1 - (i - 1) % self.w) / self.w, activeTile
  end
end

return tilemap
