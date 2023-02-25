local commonAssets = {}

function commonAssets.load()
  local itemAtlas = love.graphics.newImage("assets/items.png")
  commonAssets.items = {
    atlas = itemAtlas,
    quads = {
      scrap = love.graphics.newQuad(64, 0, 32, 32, itemAtlas),
      ore = love.graphics.newQuad(0, 0, 32, 32, itemAtlas),
      metal = love.graphics.newQuad(32, 0, 32, 32, itemAtlas),
      plastic = love.graphics.newQuad(96, 0, 32, 32, itemAtlas),
      wire = love.graphics.newQuad(0, 32, 32, 32, itemAtlas),
      pcb = love.graphics.newQuad(32, 32, 32, 32, itemAtlas),
      device = love.graphics.newQuad(64, 32, 32, 32, itemAtlas),
      powertool = love.graphics.newQuad(96, 32, 32, 32, itemAtlas),
    }
  }
end

return commonAssets
