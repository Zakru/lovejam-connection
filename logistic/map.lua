local vecmath = require "vecmath"

local map = {}
local mapMeta = { __index = {} }

local roadTex

function map.load()
  roadTex = love.graphics.newImage("assets/asphalt.png")
  roadTex:setWrap("mirroredrepeat")
end

function map.generate()
  local m = {}

  local roadVerts = {}

  function vert(x, y)
    roadVerts[#roadVerts+1] = { x,y, x/256,y/256 }
  end

  function roadSegment(sx, sy, ex, ey, w)
    local dx, dy = vecmath.normalize(ex - sx, ey - sy)
    local nx, ny = dy, -dx
    vert(sx + nx * w, sy + ny * w)
    vert(sx - nx * w, sy - ny * w)
    vert(ex + nx * w, ey + ny * w)

    vert(ex + nx * w, ey + ny * w)
    vert(sx - nx * w, sy - ny * w)
    vert(ex - nx * w, ey - ny * w)
  end

  function roadArc(x, y, r, sa, ea, w, seg)
    seg = seg or math.ceil(math.abs(sa - ea) / math.pi * 32)

    for i=1,seg do
      local starta, enda = sa + (ea - sa) * (i - 1) / seg, sa + (ea - sa) * i / seg
      local startnx, startny = math.cos(starta), math.sin(starta)
      local endnx, endny = math.cos(enda), math.sin(enda)
      vert(x + startnx * (r - w), y + startny * (r - w))
      vert(x + startnx * (r + w), y + startny * (r + w))
      vert(x + endnx * (r - w), y + endny * (r - w))

      vert(x + endnx * (r - w), y + endny * (r - w))
      vert(x + startnx * (r + w), y + startny * (r + w))
      vert(x + endnx * (r + w), y + endny * (r + w))
    end

    if ea > sa then
      return -math.sin(ea), math.cos(ea)
    else
      return math.sin(ea), -math.cos(ea)
    end
  end

  function roadArcFromTo(sx, sy, dx, dy, ex, ey, w, seg)
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

    return roadArc(x, y, math.abs(r), sa, ea, w, seg)
  end

  local currentx, currenty = 0, 0
  local dirx, diry = 1, 0

  function to(x, y)
    roadSegment(currentx, currenty, x, y, 192)
    dirx, diry = x - currentx, y - currenty
    currentx, currenty = x, y
  end

  function arcTo(x, y)
    dirx, diry = roadArcFromTo(currentx, currenty, dirx, diry, x, y, 192)
    currentx, currenty = x, y
  end

  to(512, 0)
  arcTo(1024, 512)
  to(1024, 1024)
  arcTo(2048, 2048)

  m.roadMesh = love.graphics.newMesh(roadVerts, "triangles", "static")
  m.roadMesh:setTexture(roadTex)

  return setmetatable(m, mapMeta)
end

function mapMeta.__index:draw()
  love.graphics.draw(self.roadMesh)
end

return map
