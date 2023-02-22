local vecmath = require "vecmath"

local map = {}
local mapMeta = { __index = {} }

local roadTex
local treeImage

local RoadSegment = {}
setmetatable(RoadSegment, {
  __call = function(self, tb)
    return setmetatable(tb or {}, { __index = self, __call = getmetatable(RoadSegment).__call })
  end,
})

-- start (road, ground), end (road, ground)
function RoadSegment:preferredWidth()
  return nil, nil, nil, nil
end

local DEFAULT_ROAD_WIDTH = 192
local DEFAULT_GROUND_WIDTH = 576

local function vert(x, y)
  return { x,y, x/256,y/256 }
end

local function appendQuad(verts, s1x, s1y, s2x, s2y, e1x, e1y, e2x, e2y)
  local s1, s2, e1, e2 = vert(s1x, s1y), vert(s2x, s2y), vert(e1x, e1y), vert(e2x, e2y)
  verts[#verts+1] = s1
  verts[#verts+1] = s2
  verts[#verts+1] = e1

  verts[#verts+1] = e1
  verts[#verts+1] = s2
  verts[#verts+1] = e2
end

local function appendEdgeLine(lines, sx, sy, ex, ey)
  if sx ~= ex or sy ~= ey then
    lines[#lines+1] = { sx, sy, ex, ey }
  end
end

local function appendLineQuad(verts, sx, sy, snx, sny, ex, ey, enx, eny, sw, ew, edgeLines)
  appendQuad(verts,
    sx + snx * sw, sy + sny * sw,
    sx - snx * sw, sy - sny * sw,
    ex + enx * ew, ey + eny * ew,
    ex - enx * ew, ey - eny * ew
  )
  if edgeLines then
    appendEdgeLine(edgeLines, sx - snx * sw, sy - sny * sw, ex - enx * ew, ey - eny * ew)
    appendEdgeLine(edgeLines, ex + enx * ew, ey + eny * ew, sx + snx * sw, sy + sny * sw)
  end
end

local function prevNext(segments, i)
  return segments[i-1], segments[i+1]
end

local function prevNextWidth(segments, i)
  local prev, next = prevNext(segments, i)
  local startrw, startgw, endrw, endgw
  if prev then
    startrw, startgw = select(3, prev:preferredWidth())
  end
  if next then
    endrw, endgw = next:preferredWidth()
  end
  return startrw, startgw, endrw, endgw
end

local StraightRoad = RoadSegment()

function StraightRoad:bake(mapModel, segments, i)
  local startrw, startgw, endrw, endgw = prevNextWidth(segments, i)
  startrw, startgw = startrw or DEFAULT_ROAD_WIDTH, startgw or DEFAULT_GROUND_WIDTH
  endrw, endgw = endrw or DEFAULT_ROAD_WIDTH, endgw or DEFAULT_GROUND_WIDTH

  local dx, dy = vecmath.normalize(self.ex - self.sx, self.ey - self.sy)
  local nx, ny = -dy, dx
  appendLineQuad(mapModel.roadVerts,
    self.sx, self.sy, nx, ny,
    self.ex, self.ey, nx, ny,
    startrw, endrw
  )

  appendLineQuad(mapModel.groundVerts,
    self.sx, self.sy, nx, ny,
    self.ex, self.ey, nx, ny,
    startgw, endgw,
    mapModel.edgeLines
  )
end

local ArcRoad = RoadSegment()

function ArcRoad:preferredWidth(mapModel, segments, i)
  return nil, math.min(self.r, 1024), nil, math.min(self.r, 1024)
end

function ArcRoad:bake(mapModel, segments, i)
  seg = seg or math.ceil(math.abs(self.sa - self.ea) / math.pi * 32)
  local w = DEFAULT_ROAD_WIDTH

  for i=1,seg do
    local starta, enda = self.sa + (self.ea - self.sa) * (i - 1) / seg, self.sa + (self.ea - self.sa) * i / seg
    local startnx, startny = math.cos(starta), math.sin(starta)
    local endnx, endny = math.cos(enda), math.sin(enda)
    local normalscale = self.sa < self.ea and -1 or 1

    appendLineQuad(mapModel.roadVerts,
      self.x + startnx * self.r, self.y + startny * self.r,
      normalscale * startnx, normalscale * startny,
      self.x + endnx * self.r, self.y + endny * self.r,
      normalscale * endnx, normalscale * endny,
      w, w
    )

    appendLineQuad(mapModel.groundVerts,
      self.x + startnx * self.r, self.y + startny * self.r,
      normalscale * startnx, normalscale * startny,
      self.x + endnx * self.r, self.y + endny * self.r,
      normalscale * endnx, normalscale * endny,
      math.min(self.r, 1024), math.min(self.r, 1024),
      mapModel.edgeLines
    )
  end
end

local CapRoad = RoadSegment()

function CapRoad:bake(mapModel, segments, i)
  local endrw, endgw = select(self.endPart and 1 or 3, prevNextWidth(segments, i))
  endrw, endgw = endrw or DEFAULT_ROAD_WIDTH, endgw or DEFAULT_GROUND_WIDTH

  local nx, ny = -self.dy, self.dx
  appendLineQuad(mapModel.roadVerts,
    self.x - self.dx * self.length / 2, self.y - self.dy * self.length / 2, nx, ny,
    self.x, self.y, nx, ny,
    endrw, endrw
  )

  appendLineQuad(mapModel.groundVerts,
    self.x - self.dx * self.length, self.y - self.dy * self.length, nx, ny,
    self.x, self.y, nx, ny,
    self.w, self.w,
    mapModel.edgeLines
  )

  appendEdgeLine(mapModel.edgeLines,
    self.x - self.dx * self.length + nx * self.w, self.y - self.dy * self.length + ny * self.w,
    self.x - self.dx * self.length - nx * self.w, self.y - self.dy * self.length - ny * self.w
  )
  appendEdgeLine(mapModel.edgeLines,
    self.x - nx * self.w, self.y - ny * self.w,
    self.x - nx * endgw, self.y - ny * endgw
  )
  appendEdgeLine(mapModel.edgeLines,
  self.x + nx * endgw, self.y + ny * endgw,
    self.x + nx * self.w, self.y + ny * self.w
  )
end

function map.load()
  roadTex = love.graphics.newImage("assets/asphalt.png")
  roadTex:setWrap("mirroredrepeat")
  treeImage = love.graphics.newImage("assets/tree.png")
end

function map.generate(world)
  local m = {}

  m.entities = {}

  local roadSegments = {}

  local function roadArcFromTo(sx, sy, dx, dy, ex, ey, w)
    dx, dy = vecmath.normalize(dx, dy)
    local nx, ny = dy, -dx
    local r = vecmath.length2(sx - ex, sy - ey) / (2 * (vecmath.dot(ex - sx, ey - sy, nx, ny)))
    local x, y = sx + r * nx, sy + r * ny
    local sa, ea = math.atan2(sy - y, sx - x), math.atan2(ey - y, ex - x)

    if vecmath.dot(nx, ny, sx - x, sy - y) > 0 then -- Adjust rotation direction
      if sa > ea then ea = ea + 2 * math.pi end
    else
      if sa < ea then ea = ea - 2 * math.pi end
    end

    roadSegments[#roadSegments+1] = ArcRoad { x=x, y=y, r=math.abs(r), sa=sa, ea=ea }
    if ea > sa then
      return -math.sin(ea), math.cos(ea)
    else
      return math.sin(ea), -math.cos(ea)
    end
  end

  local currentx, currenty = 0, 0
  local dirx, diry = 1, 0

  local function to(x, y)
    roadSegments[#roadSegments+1] = StraightRoad { sx=currentx, sy=currenty, ex=x, ey=y }
    dirx, diry = vecmath.normalize(x - currentx, y - currenty)
    currentx, currenty = x, y
  end

  local function arcTo(x, y)
    dirx, diry = roadArcFromTo(currentx, currenty, dirx, diry, x, y, 192)
    currentx, currenty = x, y
  end

  local function forward(d)
    m.entities[#m.entities+1] =
    to(currentx + dirx * d, currenty + diry * d)
  end

  local function turn(x, y)
    arcTo(currentx + dirx * x - diry * y, currenty + diry * x + dirx * y)
  end

  roadSegments[#roadSegments+1] = CapRoad { x=currentx, y=currenty, dx=dirx, dy=diry, w=1024, length=2048 }
  forward(2000)
  turn(1000, 500)
  forward(3000)
  turn(2000, -500)
  roadSegments[#roadSegments+1] = CapRoad { x=currentx, y=currenty, dx=-dirx, dy=-diry, w=1024, length=2048, endPart=true }

  local model = {
    roadVerts = {},
    groundVerts = {},
    edgeLines = {},
  }

  for i,segment in ipairs(roadSegments) do
    segment:bake(model, roadSegments, i)
  end

  m.roadMesh = love.graphics.newMesh(model.roadVerts, "triangles", "static")
  m.roadMesh:setTexture(roadTex)
  m.groundMesh = love.graphics.newMesh(model.groundVerts, "triangles", "static")

  m.obstacleBody = love.physics.newBody(world, 0, 0, "static")
  m.treeBatch = love.graphics.newSpriteBatch(treeImage, nil, "static")
  local TREE_DENSITY = 1/128
  local treew, treeh = treeImage:getDimensions()

  for _,line in ipairs(model.edgeLines) do
    local treeCount = math.ceil(vecmath.length(line[3] - line[1], line[4] - line[2]) * TREE_DENSITY)
    for i=1,treeCount do
      local tx, ty = vecmath.lerp(line[1], line[2], line[3], line[4], (i-1)/treeCount)
      m.treeBatch:add(tx, ty, math.random() * math.pi * 2, 1, 1, treew/2, treeh/2)
      local shape = love.physics.newCircleShape(tx, ty, treew*0.3)
      love.physics.newFixture(m.obstacleBody, shape)
    end
  end

  m.endTrigger = love.physics.newBody(world, currentx, currenty, "static")
  m.endTrigger:setAngle(math.atan2(diry, dirx))
  love.physics.newFixture(m.endTrigger, love.physics.newRectangleShape(1024, 0, 1024, 1024)):setSensor(true)

  return setmetatable(m, mapMeta)
end

function mapMeta.__index:draw()
  love.graphics.setColor(0.5, 0.5, 0.2, 1.0)
  love.graphics.draw(self.groundMesh)
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(self.roadMesh)
  love.graphics.draw(self.treeBatch)
end

return map
