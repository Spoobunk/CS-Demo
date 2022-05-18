Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

Enemy = require "scripts.entities.enemies.enemy_base"

ET = Enemy:extend()

function ET:new(x, y, collision_world)
  ET.super.new(self, x, y, collision_world)
  self.et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  local walk_grid = anim8.newGrid(57, 75, self.et_sheet:getWidth(), self.et_sheet:getHeight(), 0, 0, 2)
  local attack_grid = anim8.newGrid(97, 75, self.et_sheet:getWidth(), self.et_sheet:getHeight(), 1, 81, 2)
  self.walk_anim = anim8.newAnimation(walk_grid('1-4', 1), .1)
  self.attack_anim = anim8.newAnimation(attack_grid('1-4', 1, '1-2', 2), .5)
  --self.quad = walk_grid('1-2', 1)[1]
  self.speed = 10
  self.collider = self.collision_world:circle(self.pos.x, self.pos.y, 100)
end

function ET:update(dt)
  self.walk_anim:update(dt)
end

function ET:draw()
  self.walk_anim:draw(self.et_sheet, self.pos:unpack())
  love.graphics.setColor(255, 0, 0, 1)
  love.graphics.rectangle('line', self.pos.x, self.pos.y, self.walk_anim:getDimensions())
  --love.graphics.draw(self.et_sheet, self.quad)
  self.collider:draw()
end

function ET:getRenderPosition()
  local offsetX, offsetY = self.walk_anim:getDimensions()
  --local offsetx, offsetY = self.img:getWidth()
  return self.pos.x + offsetX, self.pos.y + offsetY
end
  
return ET