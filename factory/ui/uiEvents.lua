local uiEvents = {}

uiEvents.raw = {
  "mousepressed",
  "mousereleased",
  "mousemoved",
}

uiEvents.all = {
  "mousepressed",
  "mousereleased",
  "mousemoved",
  "mouseclicked",
  "mouseentered",
  "mouseexited",
}

function uiEvents.handle(table, handlerFactory, events)
  events = events or uiEvents.all

  for _,event in ipairs(events) do
    table[event] = handlerFactory(event)
  end
end

function uiEvents.mouseOverlaps(x, y, w, h, mx, my)
  if mx == nil or my == nil then
    mx, my = love.mouse.getPosition()
  end
  return mx >= x and mx < x + w and my >= y and my < y + h
end

return uiEvents
