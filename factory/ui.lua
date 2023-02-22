local vecmath = require "vecmath"
local factoryClient = require "factoryClient"
local uiEvents = require "ui.uiEvents"
local commonAssets = require "commonAssets"

local elementTypes = {
  layer = require "ui.layer",
  leftBar = require "ui.leftBar",
  scalingButton = require "ui.scalingButton",
  colorContainer = require "ui.colorContainer",
  uiDrawable = require "ui.uiDrawable",
  proceduralLabel = require "ui.proceduralLabel",
  vboxContainer = require "ui.vboxContainer",
}

local JOB_TAKE_TIMEOUT = 30
local JOB_FINISH_TIMEOUT = 70
local JOB_AUTO_TIME = 60

local ui = {}

local currentlyHovering = nil
local currentlyClicking = nil
local pendingTransfers = {}
local completedTransfers = {}
local jobTransfers = {}
local transferElements

local elements
local sidebars
local inventoryElements
local prompts = {}
local transfer = nil

local function onPostJob(job, transfer, errJob, errTransfer)
  if job ~= nil then
    if pendingTransfers[transfer] and transfer.status == "pending" then
      jobTransfers[job.id] = transfer
      transfer.status = "posted"
      transfer.job = job
      transfer.updateTime = love.timer.getTime()
    else
      factoryClient.cancelJob(job)
    end
  else
    if pendingTransfers[transfer] then
      transfer.status = "expired"
      transfer.updateTime = transfer.updateTime + JOB_TAKE_TIMEOUT
    end
  end
end

local function leftbarCallback(button)
  for _,bar in pairs(sidebars) do
    bar.open = bar == button.sidebar and not bar.open
  end
end

local function moneyLabel()
  return ui.money .. " ¤"
end

local function exportsColor()
  local hasCompleted = false
  for _,_ in pairs(completedTransfers) do

  end
end

function ui.load()
  local imports = love.graphics.newImage("assets/imports.png")
  local exports = love.graphics.newImage("assets/exports.png")

  transferElements = elementTypes.vboxContainer.new {
    x=8, y=96, separation = 72,
    children = {},
  }

  inventoryElements = {}
  sidebars = {
    imports = elementTypes.leftBar.new {
      children = inventoryElements,
    },
    exports = elementTypes.leftBar.new {
      children = {
        transferElements,
      },
    },
  }

  elements = {
    elementTypes.layer.new { -- Sidebars
      children = {
        sidebars.imports,
        sidebars.exports,
      },
    },
    elementTypes.layer.new { -- Top button layer
      children = {
        elementTypes.scalingButton.new { x=16 + 0 * (64+16), y=16, w=64, h=64, label=imports, cb=leftbarCallback, sidebar=sidebars.imports },
        elementTypes.scalingButton.new { x=16 + 1 * (64+16), y=16, w=64, h=64, label=exports, cb=leftbarCallback, sidebar=sidebars.exports, proceduralColor=exportsColor },
        elementTypes.proceduralLabel.new { x=16 + 2 * (64+16), y=16, getText=moneyLabel, color={0,0,0, 0.75} },
      },
    },
    elementTypes.layer.new {
      children = prompts,
    },
  }

  ui.money = 50
end

-- Result: auto, timeout, failed, success
local function completeTransfer(transfer)
  if transfer.job then
    jobTransfers[transfer.job.id] = nil
  end

  transfer.completed = true
  transfer.element.children[5].label = love.graphics.newText(love.graphics.getFont(), "Accept")

  pendingTransfers[transfer] = nil
  completedTransfers[transfer] = true
end

function ui.onUpdateJob(status, jobId)
  local transfer = jobTransfers[jobId]
  if transfer then
    if transfer.status == "posted" and status == "taken" then
      transfer.status = "taken"
      transfer.updateTime = love.timer.getTime()
    elseif transfer.status == "taken" and status == "failed" then
      transfer.status = "failed"
      completeTransfer(transfer)
    elseif transfer.status == "taken" and status == "completed" then
      transfer.status = "success"
      completeTransfer(transfer)
    elseif transfer.status == "taken" and status == "abandoned" then
      transfer.status = "expired"
    end
  end
end

local function itemCountLabel(label)
  return string.format("%d", ui.inventory[label.kind])
end

local function selectItem(button)
  ui.selectBox(button.kind)
end

local function transferAmountLabel(label)
  if transfer.amount == "" then
    return "0"
  else
    return transfer.amount
  end
end

local TRANSFER_ACTION_MONEY_LABEL = {
  sell="Income",
  buy="Cost",
}

local function transferCostLabel(label)
  if transfer.amount == "" then
    return TRANSFER_ACTION_MONEY_LABEL[transfer.action] .. ": 0 ¤"
  else
    return string.format("%s: %d ¤", TRANSFER_ACTION_MONEY_LABEL[transfer.action], tostring(tonumber(transfer.amount) * transfer.kind.value))
  end
end

local function updateTransfer()
  if transfer then
    if transfer.amount ~= "" then
      if transfer.action == "sell" then
        if tonumber(transfer.amount) > ui.inventory[transfer.kind] then
          transfer.amount = tostring(ui.inventory[transfer.kind])
        end
      elseif transfer.action == "buy" then
        if tonumber(transfer.amount) * transfer.kind.value > ui.money then
          transfer.amount = tostring(math.floor(ui.money / transfer.kind.value))
        end
      end
    end

    if transfer.amount:match("^0+$") then
      transfer.amount = ""
    end
  end
end

local TRANSFER_STATUS_TITLE = {
  pending = "Posted",
  posted = "Posted",
  expired = "Backup transit",
  taken = "In transit",
  failed = "Captured by looters",
  success = "Successfully transported <3",
  auto = "Transported by backup transit",
}
local function transferStatusLabel(label)
  if label.transfer.completed then
    return TRANSFER_STATUS_TITLE[label.transfer.status]
  else
    local eta = label.transfer.updateTime - love.timer.getTime()
    if label.transfer.status == "pending" then
      eta = eta + JOB_TAKE_TIMEOUT + JOB_FINISH_TIMEOUT
    elseif label.transfer.status == "posted" then
      eta = eta + JOB_TAKE_TIMEOUT + JOB_FINISH_TIMEOUT
    elseif label.transfer.status == "expired" then
      eta = eta + JOB_AUTO_TIME
    elseif label.transfer.status == "taken" then
      eta = eta + JOB_FINISH_TIMEOUT
    end
    return string.format("%s, ETA max %ds", TRANSFER_STATUS_TITLE[label.transfer.status], eta)
  end
end

local TRANSFER_FACTOR = {
  auto = 8,
  failed = 7,
  success = 10,
}
local function dismissJobButton(button)
  local transfer = button.transfer
  if not transfer.completed then
    if transfer.job then
      factoryClient.cancelJob(transfer.job)
      jobTransfers[transfer.job.id] = nil
    end

    pendingTransfers[transfer] = nil

    if transfer.action == "sell" then
      ui.inventory[transfer.kind] = ui.inventory[transfer.kind] + math.ceil(transfer.amount * 9 / 10)
    else
      ui.money = ui.money + math.ceil(transfer.amount * transfer.kind.value * 9 / 10)
    end
  else
    completedTransfers[transfer] = nil

    local factor = TRANSFER_FACTOR[transfer.status]
    if transfer.action == "sell" then
      ui.money = ui.money + vecmath.randRound(transfer.amount * transfer.kind.value * factor / 10)
    else
      ui.inventory[transfer.kind] = ui.inventory[transfer.kind] + vecmath.randRound(transfer.amount * factor / 10)
    end
  end

  transferElements:remove(transfer.element)
end

local function endTransfer(commit)
  if transfer ~= nil then
    for i,p in ipairs(prompts) do
      if p == transfer.prompt then
        table.remove(prompts, i)
        break
      end
    end

    if commit and transfer.amount ~= "" then
      updateTransfer()
      if transfer.action == "sell" then
        ui.inventory[transfer.kind] = ui.inventory[transfer.kind] - transfer.amount
      elseif transfer.action == "buy" then
        ui.money = ui.money - transfer.amount * transfer.kind.value
      end

      if transfer.amount == "" then
        transfer.amount = 0
      else
        transfer.amount = tonumber(transfer.amount)
      end

      transfer.status = "pending"
      transfer.updateTime = love.timer.getTime()
      local font = love.graphics.getFont()
      transfer.element = elementTypes.colorContainer.new {
        x=0, y=0, w=240, h=64, color={0,0,0, 0.5},
        children = {
          elementTypes.uiDrawable.new { drawable=commonAssets.items.atlas, quad=transfer.kind.quad, x=16, y=16 },
          elementTypes.uiDrawable.new { drawable=love.graphics.newText(font, (transfer.action == "sell" and "-" or "+") .. tostring(transfer.amount)), x=52, y=4 },
          elementTypes.uiDrawable.new { drawable=love.graphics.newText(font, (transfer.action == "sell" and "+" or "-") .. tostring(transfer.amount * transfer.kind.value) .. " ¤"), x=52, y=24 },
          elementTypes.proceduralLabel.new { getText=transferStatusLabel, x=52, y=44, transfer=transfer },
          elementTypes.scalingButton.new { label=love.graphics.newText(font, "Cancel"), x=240-64, y=0, w=64, h=32, cb=dismissJobButton, transfer=transfer },
        },
      }
      transferElements:add(transfer.element)

      pendingTransfers[transfer] = true
      factoryClient.postJob(onPostJob, { cargo=transfer.kind.id, amount=tonumber(transfer.amount) }, transfer)
    end

    transfer = nil
  end
end

local function transferButton(button)
  endTransfer(false)
  local action, kind = button.action, button.kind

  local x, y = love.mouse.getPosition()
  local font = love.graphics.getFont()
  local prompt = elementTypes.colorContainer.new {
    x=x + 64, y=y - 32, w=320, h=64, color={0,0,0, 0.5},
    children = {
      elementTypes.uiDrawable.new { drawable=love.graphics.newText(font, "Type the amount and press enter, or esc to cancel"), x=4, y=4 },
      elementTypes.proceduralLabel.new { getText=transferAmountLabel, x=4, y=26, kind=kind },
      elementTypes.proceduralLabel.new { getText=transferCostLabel, x=4, y=48, kind=kind },
    },
  }

  transfer = {
    prompt=prompt,
    amount="",
    action=action,
    kind=kind,
  }

  table.insert(prompts, prompt)
end

function ui.addInventoryElement(kind)
  local i = #inventoryElements+1
  local font = love.graphics.getFont()
  inventoryElements[i] = elementTypes.colorContainer.new {
    x=8, y=(i-1) * 72 + 96, w=240, h=64, color={0,0,0, 0.5},
    children = {
      elementTypes.scalingButton.new { label=commonAssets.items.atlas, quad=kind.quad, x=16, y=16, w=32, h=32, cb=selectItem, kind=kind },
      elementTypes.proceduralLabel.new { getText=itemCountLabel, x=52, y=30, kind=kind },
      elementTypes.scalingButton.new { label=love.graphics.newText(font, "Buy"), x=240-64, y=16, w=32, h=32, cb=transferButton, action="buy", kind=kind },
      elementTypes.scalingButton.new { label=love.graphics.newText(font, "Sell"), x=240-32, y=16, w=32, h=32, cb=transferButton, action="sell", kind=kind },
    },
  }
end

function ui.update(dt)
  updateTransfer()
  for i,element in ipairs(elements) do
    if element.update then
      element:update(dt)
    end
  end

  local time = love.timer.getTime()
  for t,_ in pairs(pendingTransfers) do
    if (t.status == "pending" or t.status == "posted") and time > t.updateTime + JOB_TAKE_TIMEOUT then
      t.status = "expired"
      t.updateTime = time
      if t.status == "posted" then
        factoryClient.cancelJob(t.job)
      end
    elseif t.status == "expired" and time > t.updateTime + JOB_AUTO_TIME or t.status == "taken" and time > t.updateTime + JOB_FINISH_TIMEOUT then
      if t.status == "taken" then
        factoryClient.cancelJob(t.job)
        t.status = "timeout"
      else
        t.status = "auto"
      end
      completeTransfer(t)
    end
  end
end

function ui.draw()
  for i,element in ipairs(elements) do
    if element.draw then
      element:draw()
    end
  end
end

uiEvents.handle(ui, function(event) return function(...)
  for i=#elements,1,-1 do
    local c = elements[i]
    local consumed = c[event] and c[event](c, ...)
    if consumed then
      return consumed
    end
  end
  return nil
end end)

function ui.mousepressed(x,y, b, t, p)
  for i=#elements,1,-1 do
    local c = elements[i]
    local consumed = c.mousepressed and c:mousepressed(x,y, b, t, p)
    if consumed then
      if b == 1 and c.mouseclicked then
        currentlyClicking = consumed
      end
      return consumed
    end
  end
  return nil
end

function ui.mousemoved(x,y, dx,dy, t)
  if currentlyClicking == nil then
    for i=#elements,1,-1 do
      local c = elements[i]
      local consumed = c.mousemoved and c:mousemoved(x,y, dx,dy, t)
      if consumed then
        if consumed ~= currentlyHovering then
          if currentlyHovering and currentlyHovering.mouseexited then
            currentlyHovering:mouseexited(x,y, dx,dy, t)
          end
          if consumed.mouseentered then
            consumed:mouseentered(x,y, dx,dy, t)
          end
          currentlyHovering = consumed
        end

        return consumed
      end
    end

    if currentlyHovering and currentlyHovering.mouseexited then
      currentlyHovering:mouseexited(x,y, dx,dy, t)
    end
    currentlyHovering = nil

    return nil
  else
    local consumed = currentlyClicking.mousemoved and currentlyClicking:mousemoved(x,y, dx,dy, t)
    return consumed
  end
end

function ui.mousereleased(x,y, b, t, p)
  for i=#elements,1,-1 do
    local c = elements[i]
    local consumed = c.mousereleased and c:mousereleased(x,y, b, t, p)
    if consumed then
      if b == 1 and currentlyClicking == consumed then
        consumed:mouseclicked(x,y, b, t, p)
        currentlyClicking = nil
      end
      return consumed
    end
  end
  return nil
end

function ui.keypressed(key, scancode, isRepeat)
  if transfer then
    if key == "backspace" then
      transfer.amount = string.sub(transfer.amount, 1, -2)
    elseif key == "return" or key == "enter" then
      endTransfer(true)
    elseif key == "escape" then
      endTransfer(false)
    end
    return true
  end

  return false
end

function ui.wheelmoved()
  return false
end

function ui.textinput(text)
  if transfer and text:match("^%d+$") then
    transfer.amount = transfer.amount .. text
    updateTransfer()
    return true
  end

  return false
end

function ui.capturingKeys()
  return transfer ~= nil
end

return ui
