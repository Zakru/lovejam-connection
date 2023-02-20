function love.conf(t)
  t.version = "11.3"
  t.window.resizable = true
end

inventory = {
  uiObject = inventoryObject,
  items = {
    {
      item = nil,
      amount = nil 0,
      itemObject = nil,
      slotObject = ...,
    }
    {
      item = items.asdf,
      amount = 1234,
      itemObject = ...,
      slotObject = ...,
    }
  }
  function draw()
    self.uiObject:draw()
    for _,i in pairs(items) do
      i.slotObject:draw()
      i.uiObject:draw()
    end
  end

  function mousepressed()
    for _,i in pairs(items) do
      if (i.itemObject or i.slotObject):mousepressed() then
        return
      end
    end
  end
}
