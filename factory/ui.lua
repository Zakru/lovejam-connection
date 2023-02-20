local vecmath = require "vecmath"
local factoryClient = require "factoryClient"

local ui = {}

local currentlyClicking = nil
local leftbarButtons
local leftbarCurrent = nil
local leftbarClosing = true
local leftbart = 0
local leftbarNext = nil
local pendingJobs = {}

function ui.load()
  local imports = love.graphics.newImage("assets/imports.png")
  local exports = love.graphics.newImage("assets/exports.png")

  leftbarButtons = {
    { image=imports, scale=0.85, name="imports" },
    { image=exports, scale=0.85, name="exports" },
  }
end

local function leftbarAabb(i)
  return 16 + (i-1) * (64 + 16), 16, 64, 64
end

local function mouseOverlaps(x, y, w, h, mx, my)
  if mx == nil or my == nil then
    mx, my = love.mouse.getPosition()
  end
  return mx >= x and mx < x + w and my >= y and my < y + h
end

local function onPostJob(job)
end

local function leftbarCallback(i)
  local name = leftbarButtons[i].name
  if name == "imports" then
    local job = { cargo="scrap", amount=200 }
    pendingJobs[#pendingJobs+1] = job
    factoryClient.postJob(onPostJob, job)
  end
  if leftbarCurrent ~= name or leftBarClosing then
    leftbarClosing = true
    leftbarNext = name
  else
    leftbarClosing = not leftbarClosing
  end
end

function ui.update(dt)
  for i,butt in ipairs(leftbarButtons) do
    local targetScale = (mouseOverlaps(leftbarAabb(i)) and not (currentlyClicking and currentlyClicking.ref == butt)) and 1 or 0.85
    butt.scale = vecmath.expApproach(butt.scale, targetScale, dt, 16)
  end

  leftbart = vecmath.approach(leftbart, leftbarClosing and 0 or 1, dt * 4)
  if leftbart == 0 and leftbarNext ~= nil then
    leftbarCurrent = leftbarNext
    leftbarNext = nil
    leftbarClosing = false
  end
end

function ui.draw()
  local leftbarx = leftbarClosing and leftbart * leftbart or 1 - (1 - leftbart) * (1 - leftbart)
  local leftbarw = 256
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", (leftbarx - 1) * leftbarw, 0, leftbarw, love.graphics.getHeight())
  for i,job in ipairs(pendingJobs) do
    love.graphics.print(string.format("%f %s %s", job.amount, job.cargo, tostring(job.id or "...")), 0, (i-1)*10)
  end
  love.graphics.setColor(1, 1, 1, 1)

  for i,butt in ipairs(leftbarButtons) do
    local x, y, w, h = leftbarAabb(i)
    love.graphics.draw(butt.image, x + w/2, y + h/2, 0, butt.scale, butt.scale, w/2, h/2)
  end
end

function ui.mousepressed(x,y, b, t, p)
  for i,butt in ipairs(leftbarButtons) do
    local bx, by, bw, bh = leftbarAabb(i)
    if mouseOverlaps(bx, by, bw, bh, x, y) then
      currentlyClicking = {
        bx, by, bw, bh,
        callback = leftbarCallback, args = {i},
        ref = butt,
      }
      return true
    end
  end

  return false
end

function ui.mousemoved()
  return currentlyClicking ~= nil
end

function ui.mousereleased(x,y, b, t, p)
  if b == 1 and currentlyClicking then
    local bx, by, bw, bh = unpack(currentlyClicking)
    if mouseOverlaps(bx, by, bw, bh, x, y) then
      if currentlyClicking.args ~= nil then
        currentlyClicking.callback(unpack(currentlyClicking.args))
      else
        currentlyClicking.callback()
      end
    end
    currentlyClicking = nil

    return true
  end

  return false
end

function ui.keypressed()
  return false
end

function ui.wheelmoved()
  return false
end

return ui
