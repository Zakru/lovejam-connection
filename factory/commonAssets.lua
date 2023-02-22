local commonAssets = {}

function commonAssets.load()
  local itemAtlas = love.graphics.newImage("assets/items.png")
  commonAssets.items = {
    atlas = itemAtlas,
    quads = {
      ore = love.graphics.newQuad(0, 0, 32, 32, itemAtlas),
      metal = love.graphics.newQuad(32, 0, 32, 32, itemAtlas),
    }
  }
end

return commonAssets
