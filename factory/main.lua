local tilemap = require "tilemap"
local item = require "item"
local vecmath = require "vecmath"

local grid
local gridMesh
local tileAtlas
local tiles = {}
local map

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
local tileRot = 1
local selectedTile = 1
local placeableTiles
local lastPlacedx, lastPlacedy = 0,0

local itemAtlas
local items = {}
local itemBatch
local freeItems = {}
local itemMap = {}

local itemTickTimer = 0

local function initItem(it, props)
  it.kind = props.kind
  it.id = props.id
  it.x = props.x
  it.y = props.y
  it.quad = props.quad
end

local function spawnItem(props)
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
    itemBatch:add(props.quad, 0, 0)
    initItem(it, props)
    it:spawn()
    return #items
  end
end

local function screenToWorld(x, y)
  local w, h = love.graphics.getDimensions()
  local z = math.exp(-zoom * 0.2)
  return (x - w/2) * z + camx, (y - h/2) * z + camy
end

local function worldToTile(x, y)
  return math.floor(x / 64), math.floor(y / 64)
end

local function swapTile(new)
  selectedTile = new
  tileRot = tileRot % (#new - 1) + 1
end

function love.load()
  love.graphics.setDefaultFilter("nearest")
  grid = love.graphics.newImage("assets/grid.png")
  grid:setWrap("repeat")
  gridMesh = love.graphics.newMesh({{0, 0, 0, 0}, {1, 0, 1, 0}, {0, 1, 0, 1}, {1, 1, 1, 1}}, "strip", "static")
  gridMesh:setTexture(grid)
  gridShader = love.graphics.newShader(gridFrag, gridVert)


  itemAtlas = love.graphics.newImage("assets/items.png")
  items.ore = love.graphics.newQuad(0, 0, 32, 32, itemAtlas)
  itemBatch = love.graphics.newSpriteBatch(itemAtlas, 1024, "stream")

  spawnItem({ x=0, y=0, kind="materials", id="ore", quad=items.ore })

  tileAtlas = love.graphics.newImage("assets/tiles.png")

  local conveyorQuad = love.graphics.newQuad(0, 0, 64, 64, tileAtlas)
  tiles.rconveyor = { is="conveyor", quad=conveyorQuad, dx= 1, dy= 0, r=0 }
  tiles.dconveyor = { is="conveyor", quad=conveyorQuad, dx= 0, dy= 1, r=math.pi * 0.5 }
  tiles.lconveyor = { is="conveyor", quad=conveyorQuad, dx=-1, dy= 0, r=math.pi }
  tiles.uconveyor = { is="conveyor", quad=conveyorQuad, dx= 0, dy=-1, r=math.pi * -0.5 }

  local heaterQuad = love.graphics.newQuad(128, 0, 64, 64, tileAtlas)
  tiles.hheater = { is="heater", quad=heaterQuad, dx=1, dy=0 }
  tiles.vheater = { is="heater", quad=heaterQuad, dx=0, dy=1, r=math.pi * 0.5 }

  placeableTiles = {
    { tiles.rconveyor, tiles.dconveyor, tiles.lconveyor, tiles.uconveyor },
    { tiles.hheater, tiles.vheater, tiles.hheater, tiles.vheater },
  }

  map = tilemap.new(tileAtlas, 64, 64, 64)
  map.items = {}
end

function love.update(dt)
  itemTickTimer = itemTickTimer - dt
  local doTick = false
  if itemTickTimer <= 0 then
    doTick = true
    itemTickTimer = 1
  end

  -- Update and despawn items
  for i,it in ipairs(items) do
    if it.alive then
      if doTick then
        local tileOn = map:getTile(it.x, it.y)
        it.px, it.py = it.x, it.y
        local mx, my = 0, 0
        if tileOn then
          if tileOn.is == "conveyor" then
            mx = tileOn.dx
            my = tileOn.dy
          elseif tileOn.is == "heater" then
            if it.heatTicks == nil then
              it.heatTicks = 1
            else
              mx = it.dx
              my = it.dy
            end
          end

          if mx ~= 0 or my ~= 0 then
            local tx, ty = it.x + mx, it.y + my
            local target = map:getTile(tx, ty)
            local canMove = true

            if target then
              if target.is == "conveyor" then
                canMove = vecmath.dot(target.dx, target.dy, mx, my) >= 0
              elseif target.is == "heater" then
                if target.dx * mx == 0 and target.dy * my == 0 then
                  canMove = false
                end
              end
            end

            if canMove then
              it.x, it.y = tx, ty
              it.dx, it.dy = mx, my

              if tileOn.is == "heater" then
                it.heatTicks = nil
              end
            end
          end
        end
      end
      local vx, vy = vecmath.lerp(it.px, it.py, it.x, it.y, math.min(1 - itemTickTimer, 1))
      itemBatch:set(i, vx * 64 + 32, vy * 64 + 32, 0, 1, 1, 16, 16)
    end
  end
end

function love.draw()
  love.graphics.push()
  local w, h = love.graphics.getDimensions()
  love.graphics.translate(w/2, h/2) -- Center
  love.graphics.scale(math.exp(zoom * 0.2))
  love.graphics.translate(-camx, -camy)

  love.graphics.setShader(gridShader)
  love.graphics.draw(gridMesh)
  love.graphics.setShader()

  map:draw()
  love.graphics.draw(itemBatch)

  love.graphics.push("all")
  love.graphics.setColor(0.1, 1, 0.1, 0.75)
  local tx, ty = worldToTile(screenToWorld(love.mouse.getPosition()))
  love.graphics.draw(tileAtlas, placeableTiles[selectedTile][tileRot].quad, tx * 64 + 32, ty * 64 + 32, placeableTiles[selectedTile][tileRot].r or 0, 1, 1, 32, 32)
  love.graphics.pop()

  love.graphics.pop()
end

function love.mousepressed(x,y, b, t, p)
  local wx, wy = screenToWorld(x, y)
  local tx, ty = worldToTile(wx, wy)

  if b == 1 then
    map:setTile(tx, ty, placeableTiles[selectedTile][tileRot])
    lastPlacedx, lastPlacedy = tx, ty
  elseif b == 2 then
    selectedTile = selectedTile % #placeableTiles + 1
  end
end

local rotFromD = {
  [-1] = { [0] = 3 },
  [0] = { [-1] = 4, [1] = 2 },
  [1] = { [0] = 1 },
}
function love.mousemoved(x, y, dx, dy, istouch)
  local wx, wy = screenToWorld(x, y)
  local tx, ty = worldToTile(wx, wy)

  if love.mouse.isDown(1) then
    if tx ~= lastPlacedx or ty ~= lastPlacedy then
      if math.abs(tx - lastPlacedx) + math.abs(ty - lastPlacedy) == 1 then
        tileRot = rotFromD[tx - lastPlacedx][ty - lastPlacedy]
        map:setTile(lastPlacedx, lastPlacedy, placeableTiles[selectedTile][tileRot])
      end
      map:setTile(tx, ty, placeableTiles[selectedTile][tileRot])
      lastPlacedx, lastPlacedy = tx, ty
    end
  elseif love.mouse.isDown(3) then
    camx = camx - dx * math.exp(-zoom * 0.2)
    camy = camy - dy * math.exp(-zoom * 0.2)
  end
end

function love.wheelmoved(x, y)
  if love.keyboard.isDown("lctrl") then
    zoom = zoom + y
  else
    tileRot = (tileRot - y + #placeableTiles[selectedTile] - 1) % #placeableTiles[selectedTile] + 1
  end
end
