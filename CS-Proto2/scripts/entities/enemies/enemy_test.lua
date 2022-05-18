Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

AnimComponent = require "scripts.entities.enemies.enemy_testanim"

Enemy = require "scripts.entities.enemies.enemy_base"

ET = Enemy:extend()

function ET:new(x, y, collision_world)
  ET.super.new(self, x, y, collision_world)
  self.ETAnim = AnimComponent(self)
  --self.quad = walk_grid('1-2', 1)[1]
  self.speed = 10
  self.collider = self.collision_world:circle(self.pos.x, self.pos.y, 100)
  self.collider.tag = "Enemy"
  self.collider.object = self
end

function ET:update(dt)
  ET.super.update(self, dt)
  self.ETAnim:update(dt)
end

function ET:draw()
  self.ETAnim:draw(self.pos:unpack())
  love.graphics.setColor(255, 0, 0, 1)
  --love.graphics.rectangle('line', self.pos.x, self.pos.y, self.ETAnim:getCurrentAnim():getDimensions())
  love.graphics.points(self.pos:unpack())
  --love.graphics.draw(self.et_sheet, self.quad)
  self.collider:draw()
  love.graphics.line(self.pos.x - 30, self:getRenderPosition(), self.pos.x + 30, self:getRenderPosition())
  love.graphics.setColor(255, 255, 255, 1)
end

function ET:alertedToPlayer()
  self.ETAnim:switchAnimation('idle')
end

function ET:getRenderPosition()
  local oy = self.ETAnim:getBaseImageOffset().y
  return math.floor((self.pos.y + oy) + 0.5)
end
  
return ET