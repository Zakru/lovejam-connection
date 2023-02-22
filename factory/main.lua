local tilemap = require "tilemap"
local item = require "item"
local vecmath = require "vecmath"
local ui = require "ui"
local factoryClient = require "factoryClient"
local activeBox = require "tiles.box"
local activeEbox = require "tiles.ebox"
local commonAssets = require "commonAssets"

local grid
local gridMesh
local tileAtlas
local tiles = {}
local maps = {}

local gridFrag = [[
  vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 texturecolor = Texel(tex, texture_coords);
    return texturecolor * color;
  }
]]

local gridVert = [[
  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec4 screen_vertex = vec4(2.0 * vec2(VertexTexCoord.x, -VertexTexCoord.y) + vec2(-1.0, 1.0), 0.0, 1.0);
    mat4 inverse_scale = mat4(1.0);
    inverse_scale[0][0] = 1.0 / 64.0 / TransformProjectionMatrix[0][0];
    inverse_scale[1][1] = 1.0 / 64.0 / TransformProjectionMatrix[1][1];
    VaryingTexCoord = (inverse_scale * vec4(screen_vertex.xy - TransformProjectionMatrix[3].xy, 0.0, 1.0));
    return screen_vertex;
  }
]]

local gridShader

local zoom = 0
local camx, camy = 0,0
local camz = 0
local camvelx, camvely = 0,0
local tileRot = 1
local selectedTile
local selectedActive = nil
local lastPlacedx, lastPlacedy = 0,0

local items = {}
local itemBatch
local freeItems = {}
local itemMap = {}
local itemKinds = {}

local itemTickTimer = 0
local tickCount = 0

local inventory = {}

local function addItem(kind, count)
  count = count or 1
  if inventory[kind] then
    inventory[kind] = inventory[kind] + count
  else
    inventory[kind] = count
    ui.addInventoryElement(kind)
  end
end

local function hasItem(kind, count)
  count = count or 1
  return inventory[kind] and inventory[kind] >= count
end

local function tryRemoveItem(kind, count)
  count = count or 1
  local prevCount = inventory[kind]
  if prevCount and prevCount >= count then
    inventory[kind] = prevCount - count
    return true
  else
    return false
  end
end

local function getItemAt(x, y)
  for i,it in ipairs(items) do
    if it.alive and it.x == x and it.y == y then
      return i
    end
  end
  return nil
end

local function initItem(it, props)
  for k,v in pairs(props) do
    it[k] = v
  end
end

local function spawnItem(props)
  if getItemAt(props.x, props.y) then
    return nil
  end
  if #freeItems > 0 then
    local i = freeItems[#freeItems]
    freeItems[#freeItems] = nil
    local it = items[i]
    initItem(it, props)
    it:spawn()
    return i
  else
    local it = item.new()
    items[#items+1] = it
    itemBatch:add(props.kind.quad, 0, 0)
    initItem(it, props)
    it:spawn()
    return #items
  end
end

local function spawnItemFromInventory(props)
  if hasItem(props.kind) then
    local item = spawnItem(props)
    if item then
      tryRemoveItem(props.kind)
    end
    return item
  else
    return nil
  end
end

local function despawnItem(i)
  local it = items[i]
  if it and it.alive then
    it:despawn()
    itemBatch:set(i, 0, 0, 0, 0, 0)
    freeItems[#freeItems+1] = i
    return it.kind
  end
  return nil
end

local function despawnItemToInventory(i)
  local kind = despawnItem(i)
  if kind then
    addItem(kind)
  end
end

local function zoomScale(factor)
  return math.exp(-camz * 0.2 * (factor or 1))
end

local function screenToWorld(x, y)
  local w, h = love.graphics.getDimensions()
  local z = zoomScale()
  return (x - w/2) * z + camx, (y - h/2) * z + camy
end

local function worldToTile(x, y)
  return math.floor(x / 64), math.floor(y / 64)
end

local function swapTile(new, active)
  selectedTile = new
  selectedActive = active
end

local function chunkCoords(x, y)
  local cx, cy = (x % 64 + 64) % 64, (y % 64 + 64) % 64
  return (x - cx) / 64, (y - cy) / 64, cx, cy
end

local function getTile(x, y)
  local chunkx, chunky, cx, cy = chunkCoords(x, y)
  local map = maps[chunkx] and maps[chunkx][chunky]
  if map then
    return map:getTile(cx, cy)
  end
end

local function setTile(x, y, tile, replace, activeInit)
  local chunkx, chunky, cx, cy = chunkCoords(x, y)
  local mapCol = maps[chunkx]
  if tile ~= nil then
    if not mapCol then
      mapCol = {}
      maps[chunkx] = mapCol
    end
    local map = mapCol[chunky]
    if not map then
      map = tilemap.new(tileAtlas, 64, 64, 64)
      map.items = {}
      mapCol[chunky] = map
    end
    if not replace then
      local existing = map:getTile(cx, cy)
      if existing and existing.is ~= "conveyor" and existing.is ~= tile.is then
        return
      end
    end
    map:setTile(cx, cy, tile, activeInit)
  else
    if not mapCol then
      return
    end
    local map = mapCol[chunky]
    if not map then
      return
    end
    map:setTile(cx, cy, tile, activeInit)
    if map.tileCount == 0 then
      mapCol[chunky] = nil
    end
  end
end

local function setTileState(x, y, tile)
  local chunkx, chunky, cx, cy = chunkCoords(x, y)
  local map = maps[chunkx][chunky]
  map.map[map:index(cx, cy)] = tile
end

local function tileToPlace()
  local current = selectedTile
  if selectedTile.canRotate then
    current = current[tileRot]
  end

  if selectedTile.multipleStates then
    current = current[1]
  end

  return current
end

local rotToDirTable = {
  {1, 0}, {0, 1}, {-1, 0}, {0, -1}
}

local function rotToDir(r)
  return unpack(rotToDirTable[r])
end

local function selectBox(kind)
  swapTile(tiles.box, { itemKind=kind })
end

function love.load()
  love.graphics.setDefaultFilter("nearest")
  commonAssets.load()

  grid = love.graphics.newImage("assets/grid.png")
  grid:setWrap("repeat")
  gridMesh = love.graphics.newMesh({{0, 0, 0, 0}, {1, 0, 1, 0}, {0, 1, 0, 1}, {1, 1, 1, 1}}, "strip", "static")
  gridMesh:setTexture(grid)
  gridShader = love.graphics.newShader(gridFrag, gridVert)

  itemBatch = love.graphics.newSpriteBatch(commonAssets.items.atlas, 1024, "stream")
  itemKinds.metal = { id="metal", quad = commonAssets.items.quads.metal, value = 120 }
  itemKinds.ore = { id="ore", quad = commonAssets.items.quads.ore, value = 100, heatsInto = itemKinds.metal, heatTime = 10 }
  itemKinds.scrap = { id="scrap", quad = commonAssets.items.quads.scrap, value = 1 }

  tileAtlas = love.graphics.newImage("assets/tiles.png")
  love.graphics.setDefaultFilter("linear")

  local conveyorQuad = love.graphics.newQuad(0, 0, 64, 64, tileAtlas)
  tiles.conveyor = {
    { is="conveyor", quad=conveyorQuad, dx= 1, dy= 0, r=0 },
    { is="conveyor", quad=conveyorQuad, dx= 0, dy= 1, r=math.pi * 0.5 },
    { is="conveyor", quad=conveyorQuad, dx=-1, dy= 0, r=math.pi },
    { is="conveyor", quad=conveyorQuad, dx= 0, dy=-1, r=math.pi * -0.5 },
    canRotate = true,
  }

  local splitterQuad = love.graphics.newQuad(0, 64, 64, 64, tileAtlas)
  tiles.splitter = { canRotate = true, multipleStates=true }
  for i=1,4 do
    local dx, dy = rotToDir(i)
    tiles.splitter[i] = {
      { is="splitter", quad=splitterQuad, dx=dx, dy=dy, d=i, i=1, r=math.pi * 0.5 * (i - 1) },
      { is="splitter", quad=splitterQuad, dx=dx, dy=dy, d=i, i=2, r=math.pi * 0.5 * (i - 1) },
      { is="splitter", quad=splitterQuad, dx=dx, dy=dy, d=i, i=3, r=math.pi * 0.5 * (i - 1) },
    }
  end

  local heaterQuad = love.graphics.newQuad(128, 0, 64, 64, tileAtlas)
  tiles.heater = {
    { is="heater", quad=heaterQuad, dx=1, dy=0 },
    { is="heater", quad=heaterQuad, dx=0, dy=1, r=math.pi * 0.5 },
    canRotate = true,
  }
  tiles.heater[3] = tiles.heater[1]
  tiles.heater[4] = tiles.heater[2]

  local boxQuad = love.graphics.newQuad(64, 0, 64, 64, tileAtlas)
  local boxFgQuad = love.graphics.newQuad(64, 64, 64, 64, tileAtlas)
  tiles.box = {
    { is="box", quad=boxQuad, fgQuad=boxFgQuad, activeTile=activeBox, dx= 1, dy= 0, r=0 },
    { is="box", quad=boxQuad, fgQuad=boxFgQuad, activeTile=activeBox, dx= 0, dy= 1, r=math.pi * 0.5 },
    { is="box", quad=boxQuad, fgQuad=boxFgQuad, activeTile=activeBox, dx=-1, dy= 0, r=math.pi },
    { is="box", quad=boxQuad, fgQuad=boxFgQuad, activeTile=activeBox, dx= 0, dy=-1, r=math.pi * -0.5 },
    canRotate = true,
  }

  selectedTile = tiles.conveyor

  factoryClient.connect("127.0.0.1", 5483)

  local musicSource = love.audio.newSource("assets/music.ogg", "stream")
  musicSource:setLooping(true)
  musicSource:play()

  ui.inventory = inventory
  ui.selectBox = selectBox
  ui.load()

  setTile(0, 0, tiles.box[1], nil, { itemKind=itemKinds.ore })
  setTile(10, 0, tiles.box[3])

  addItem(itemKinds.ore, 5)
end

local tickItem
local function tryMove(it, mx, my)
  local tx, ty = it.x + mx, it.y + my
  local target, activeTarget = getTile(tx, ty)

  if not target then
    return false
  end

  if target.is == "conveyor" then
    if vecmath.dot(target.dx, target.dy, mx, my) < 0 then
      return false
    end
  elseif target.is == "splitter" then
    if vecmath.dot(target.dx, target.dy, mx, my) <= 0 then
      return false
    end
  elseif target.is == "heater" then
    if target.dx * mx == 0 and target.dy * my == 0 then
      return false
    end
  elseif target.is == "box" then
    if activeTarget.itemKind or vecmath.dot(target.dx, target.dy, mx, my) >= 0 then
      return false
    end
  else
    return false
  end

  local i = getItemAt(tx, ty)
  if i then
    it.current = true -- Loop handling
    tickItem(i)
    it.current = nil
    if getItemAt(tx, ty) then
      return false
    end
  end

  -- Actually move
  it.x, it.y = tx, ty
  it.dx, it.dy = mx, my
  return true
end

tickItem = function(i)
  local it = items[i]
  if it.current then
    -- Loop detected. Temporarily remove this item from any coordinates and return.
    -- Only way we get here is if there is a loop, and this unwinds it nicely.
    it.x, it.y = nil, nil
  elseif it.lastTick < tickCount then
    it.lastTick = tickCount
    local tx, ty = it.x, it.y
    local tileOn = getTile(tx, ty)
    it.px, it.py = it.x, it.y
    if tileOn then
      if tileOn.is == "conveyor" then
        tryMove(it, tileOn.dx, tileOn.dy)
      elseif tileOn.is == "splitter" then
        for _=1,3 do
          local moved = tryMove(it, rotToDir((tileOn.d + tileOn.i - 3) % 4 + 1))
          tileOn = tiles.splitter[tileOn.d][tileOn.i % 3 + 1]
          setTileState(tx, ty, tileOn)
          if moved then
            break
          end
        end
      elseif tileOn.is == "heater" then
        if it.heatTicks == nil then
          it.heatTicks = 1
        elseif it.kind.heatTime == nil or it.heatTicks == it.kind.heatTime then
          if it.kind.heatsInto ~= nil then
            it.kind = it.kind.heatsInto
          end
          if tryMove(it, it.dx or 0, it.dy or 0) then
            it.heatTicks = nil
          end
        else
          it.heatTicks = it.heatTicks + 1
        end
      elseif tileOn.is == "box" then
        tryMove(it, tileOn.dx, tileOn.dy)
      end
    end
  end
end

function love.update(dt)
  factoryClient.update()

  itemTickTimer = itemTickTimer - dt
  local doTick = false
  if itemTickTimer <= 0 then
    doTick = true
    itemTickTimer = 1
    tickCount = tickCount + 1
  end

  -- Update active tiles
  if doTick then
    for cx,col in pairs(maps) do
      for cy,map in pairs(col) do
        for x,y, activeTile in map:iterActiveTiles() do
          x, y = cx * 64 + x, cy * 64 + y
          if activeTile.kind == "box" then
            if activeTile.itemKind then
              spawnItemFromInventory { x=x, y=y, kind=activeTile.itemKind, spawner=activeTile }
            else
              local i = getItemAt(x, y)
              if i then
                despawnItemToInventory(i)
              end
            end
          end
        end
      end
    end
  end

  -- Update and despawn items
  for i,it in ipairs(items) do
    if it.alive then
      if doTick then
        tickItem(i)
      end
      local vx, vy = vecmath.lerp(it.px, it.py, it.x, it.y, math.min(1 - itemTickTimer, 1))
      itemBatch:set(i, it.kind.quad, vx * 64 + 32, vy * 64 + 32, 0, 1, 1, 16, 16)
    end
  end

  local camaccelx, camaccely = 0, 0
  if love.keyboard.isDown("w") then camaccely = camaccely - 1 end
  if love.keyboard.isDown("a") then camaccelx = camaccelx - 1 end
  if love.keyboard.isDown("s") then camaccely = camaccely + 1 end
  if love.keyboard.isDown("d") then camaccelx = camaccelx + 1 end
  camaccelx, camaccely = vecmath.scale(camaccelx, camaccely, 64*8 * (love.keyboard.isDown("lshift") and 4 or 1))

  camz = vecmath.expApproach(camz, zoom, dt, 8)

  camvelx = vecmath.expApproach(camvelx, camaccelx, dt, 8)
  camvely = vecmath.expApproach(camvely, camaccely, dt, 8)
  camx = camx + camvelx * zoomScale(0.5) * dt
  camy = camy + camvely * zoomScale(0.5) * dt

  ui.update(dt)
end

function love.draw()
  love.graphics.push()
  local w, h = love.graphics.getDimensions()
  love.graphics.translate(w/2, h/2) -- Center
  love.graphics.scale(zoomScale(-1))
  love.graphics.translate(-camx, -camy)

  love.graphics.setShader(gridShader)
  love.graphics.draw(gridMesh)
  love.graphics.setShader()

  for x,col in pairs(maps) do
    for y,map in pairs(col) do
      love.graphics.push()
      love.graphics.translate(x*64*64, y*64*64)
      map:draw()
      love.graphics.pop()
    end
  end

  love.graphics.draw(itemBatch)

  for x,col in pairs(maps) do
    for y,map in pairs(col) do
      love.graphics.push()
      love.graphics.translate(x*64*64, y*64*64)
      map:drawForeground()
      love.graphics.pop()
    end
  end

  for cx,col in pairs(maps) do
    for cy,map in pairs(col) do
      for x,y, activeTile in map:iterActiveTiles() do
        if activeTile.draw then
          x, y = cx * 64 + x, cy * 64 + y
          love.graphics.push()
          love.graphics.translate(x*64, y*64)
          activeTile:draw()
          love.graphics.pop()
        end
      end
    end
  end

  love.graphics.push("all")
  love.graphics.setColor(0.1, 1, 0.1, 0.75)
  local tx, ty = worldToTile(screenToWorld(love.mouse.getPosition()))
  local toPlace = tileToPlace()
  love.graphics.draw(tileAtlas, toPlace.quad, tx * 64 + 32, ty * 64 + 32, toPlace.r or 0, 1, 1, 32, 32)
  if toPlace.fgQuad then
    love.graphics.draw(tileAtlas, toPlace.fgQuad, tx * 64 + 32, ty * 64 + 32, toPlace.r or 0, 1, 1, 32, 32)
  end
  love.graphics.pop()

  love.graphics.pop()

  ui.draw()
end

function love.mousepressed(x,y, b, t, p)
  if ui.mousepressed(x,y, b, t, p) then return end

  local wx, wy = screenToWorld(x, y)
  local tx, ty = worldToTile(wx, wy)

  if b == 1 then
    setTile(tx, ty, tileToPlace(), nil, selectedActive)
    lastPlacedx, lastPlacedy = tx, ty
  elseif b == 2 then
    setTile(tx, ty, nil, true)
    lastPlacedx, lastPlacedy = tx, ty
  end
end

function love.mousereleased(x,y, b, t, p)
  if b == 1 then
    lastPlacedx, lastPlacedy = nil
  end
  if ui.mousereleased(x,y, b, t, p) then return end
end

function love.keypressed(key, scancode, isRepeat)
  if ui.keypressed(key, scancode, isRepeat) or ui.capturingKeys() then return end

  if key == "1" then
    swapTile(tiles.conveyor)
  elseif key == "2" then
    swapTile(tiles.splitter)
  elseif key == "3" then
    swapTile(tiles.heater)
  elseif key == "4" then
    swapTile(tiles.box)
  elseif key == "r" then
    local dir = love.keyboard.isDown("lshift") and -1 or 1
    tileRot = (tileRot + dir + 3) % 4 + 1
  end
end

function love.textinput(text)
  if ui.textinput(text) then return end
end

local rotFromD = {
  [-1] = { [0] = 3 },
  [0] = { [-1] = 4, [1] = 2 },
  [1] = { [0] = 1 },
}
function love.mousemoved(x, y, dx, dy, istouch)
  if ui.mousemoved(x, y, dx, dy, istouch) then return end

  local wx, wy = screenToWorld(x, y)
  local tx, ty = worldToTile(wx, wy)

  if love.mouse.isDown(1) then
    if lastPlacedx ~= nil and (tx ~= lastPlacedx or ty ~= lastPlacedy) then
      if math.abs(tx - lastPlacedx) + math.abs(ty - lastPlacedy) == 1 then
        tileRot = rotFromD[tx - lastPlacedx][ty - lastPlacedy]
        setTile(lastPlacedx, lastPlacedy, tileToPlace(), false)
      end
      setTile(tx, ty, tileToPlace(), false)
      lastPlacedx, lastPlacedy = tx, ty
    end
  elseif love.mouse.isDown(2) then
    if tx ~= lastPlacedx or ty ~= lastPlacedy then
      setTile(tx, ty, nil, true)
      lastPlacedx, lastPlacedy = tx, ty
    end
  elseif love.mouse.isDown(3) then
    camx = camx - dx * zoomScale()
    camy = camy - dy * zoomScale()
  end
end

function love.wheelmoved(x, y)
  if ui.wheelmoved(x, y) then return end
  zoom = math.min(math.max(zoom + y, -5), 5)
end
