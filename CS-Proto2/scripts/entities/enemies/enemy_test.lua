Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

AnimComponent = require "scripts.entities.entity_anim_base"

Enemy = require "scripts.entities.enemies.enemy_base"

ET = Enemy:extend()

function ET:new(x, y, collision_world)
  ET.super.new(self, x, y, collision_world)
  local et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  self.Anim = AnimComponent(math.floor(47 / 2), 23, et_sheet)
  local walk_grid = anim8.newGrid(57, 75, et_sheet:getWidth(), et_sheet:getHeight(), 0, 0, 2)
  local attack_grid = anim8.newGrid(97, 75, et_sheet:getWidth(), et_sheet:getHeight(), 1, 79, 2)
  local idle_grid = anim8.newGrid(47, 78, et_sheet:getWidth(), et_sheet:getHeight(), 235, 0, 2)
  self.Anim:addAnimation('walk', anim8.newAnimation(walk_grid('1-4', 1), .1), 75)
  self.Anim:addAnimation('attack', anim8.newAnimation(attack_grid('1-4', 1, '1-2', 2), .1), 75)
  self.Anim:addAnimation('idle', anim8.newAnimation(idle_grid('1-2', 1), .5), 77)
  self.speed = 10
  self.collider = self.collision_world:circle(self.pos.x, self.pos.y, 100)
  self.collider.tag = "Enemy"
  self.collider.object = self
end

function ET:update(dt)
  ET.super.update(self, dt)
  self.Anim:update(dt)
end

function ET:draw()
  self.Anim:draw(self.pos:unpack())
  love.graphics.setColor(255, 0, 0, 1)
  --love.graphics.rectangle('line', self.pos.x, self.pos.y, self.Anim:getCurrentAnim():getDimensions())
  love.graphics.points(self.pos:unpack())
  --love.graphics.draw(self.et_sheet, self.quad)
  self.collider:draw()
  love.graphics.line(self.pos.x - 30, self:getRenderPosition(), self.pos.x + 30, self:getRenderPosition())
  love.graphics.setColor(255, 255, 255, 1)
end

function ET:alertedToPlayer()
  self.Anim:switchAnimation('walk')
end

function ET:getRenderPosition()
  local oy = self.Anim:getBaseImageOffset().y
  return math.floor((self.pos.y + oy) + 0.5)
end
  
return ET