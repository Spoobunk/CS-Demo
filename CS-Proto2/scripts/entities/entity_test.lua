Scenery = require "scripts.entities.scenery.scenery_base"

e_test = Scenery:extend()

function e_test:new(x, y)
  self.name = "e test"
  self.x, self.y = x, y
  self.img = love.graphics.newImage("assets/test/sprites/scenery test.png")
end

function e_test:draw()
  love.graphics.draw(self.img, self.x, self.y)
  love.graphics.points(self.x, self.y + self.img:getHeight() - 8)
end

function e_test:getRenderPosition()
  return self.y + self.img:getHeight() - 8
end

return e_test