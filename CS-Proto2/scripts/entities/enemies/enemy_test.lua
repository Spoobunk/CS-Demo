Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

AnimComponent = require "scripts.entities.entity_anim_base"
MoveComponent = require "scripts.entities.entity_move_base"

basic_attack = require "scripts.entities.enemies.attack procedures.attack_basic"

Enemy = require "scripts.entities.enemies.enemy_base"

ET = Enemy:extend()
ET.state = {
  idle = {
    vulnerable = true
  },
  alerted = {
    vulnerable = true
  },
  attacking = {
    vulnerable = true
  }
}

ET.attacks = {
    basic = basic_attack
}
function ET:new(x, y, collision_world)
  ET.super.new(self, x, y, collision_world)
  self.state = ET.state.idle
  self.current_attack = nil
  
  --Anim setup
  local et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  self.Anim = AnimComponent(math.floor(47 / 2), 23, et_sheet)
  local walk_grid = anim8.newGrid(57, 75, et_sheet:getWidth(), et_sheet:getHeight(), 0, 0, 2)
  local attack_grid = anim8.newGrid(97, 75, et_sheet:getWidth(), et_sheet:getHeight(), 1, 79, 2)
  local idle_grid = anim8.newGrid(47, 78, et_sheet:getWidth(), et_sheet:getHeight(), 235, 0, 2)
  self.Anim:addAnimation('walk', anim8.newAnimation(walk_grid('1-4', 1), .1), 75)
  self.Anim:addAnimation('attack_windup', anim8.newAnimation(attack_grid('1-2', 1), .1, 'pauseAtEnd'), 75)
  self.Anim:addAnimation('attack', anim8.newAnimation(attack_grid('3-4', 1, '1-2', 2), .1), 75)
  self.Anim:addAnimation('idle', anim8.newAnimation(idle_grid('1-2', 1), .5), 77)
  
  -- super slippery movement
  --self.Move = MoveComponent(50, 0.15, 1200)
  self.Move = MoveComponent(4, 0.09, 150)
    
  self.speed = 3
  self.collider = self.collision_world:circle(self.pos.x, self.pos.y, 100)
  self.collider.tag = "Enemy"
  self.collider.object = self
  
  -- this is set when the enemy is alerted to the player
  self.trigger_attack_area = nil
  
  
  self.collision_resolution = {
    Player = function() self:alertedToPlayer() end,
    Attack_Trigger = function() self:getInAttackPosition() end
  }
  
  self.following_player = false
  -- variable that saves whether the player was to the right or left of the entity during the last update. For comparing with the current position of the player to decide when to flip the sprite horizontally.
  self.player_was_to = "left"
end

function ET:update(dt)
  ET.super.update(self, dt)
  self.Anim:update(dt)
  self.Move:update(dt)
  if(self.current_attack) then
    self.current_attack:update(dt)
  end

   self.pos = self.pos + self.Move:getMovementStep(dt)
  
  if(self.following_player and self.player) then
    self.Move:setMovementSettings(self.toward_player)
    --self.pos = self.pos + (self.toward_player * self.speed) * (1+dt)
  end
  
  if(self.trigger_attack_area) then
    self.trigger_attack_area:moveTo(self.player.position:unpack())
  end
  
  if(self.player) then
    if self.player_was_to ~= self.player_is_to then self.Anim:flipSpriteHorizontal() end
  end
  
  self.player_was_to = self.player_is_to
  
  self.collider:moveTo(self.pos:unpack())
end

function ET:draw()
  self.Anim:draw(self.pos.x, self.pos.y, -1)
  love.graphics.setColor(255, 0, 0, 1)
  --love.graphics.rectangle('line', self.pos.x, self.pos.y, self.Anim:getCurrentAnim():getDimensions())
  love.graphics.points(self.pos:unpack())
  if(self.trigger_attack_area) then
    self.trigger_attack_area:draw()
  end
  --love.graphics.draw(self.et_sheet, self.quad)
  self.collider:draw()
  love.graphics.line(self.pos.x - 30, self:getRenderPosition(), self.pos.x + 30, self:getRenderPosition())
  love.graphics.setColor(255, 255, 255, 1)
end

function ET:alertedToPlayer()
  if(self.state == ET.state.idle) then
    self.state = ET.state.alerted
    self.Anim:switchAnimation('walk')
    self.trigger_attack_area = self.collision_world:circle(self.player.position.x, self.player.position.y, 20)
    self.trigger_attack_area.tag = "Attack_Trigger"
    self.trigger_attack_area.object = self
    self.following_player = true
  end
end

function ET:getInAttackPosition()
  if(self.state == ET.state.alerted) then
    self.state = ET.state.attacking
    self.current_attack = basic_attack(self)
    --[[self.following_player = false
    local target = vector(self.player.position.x + 10, self.player.position.y)
    local toward_target = target - self.pos
    toward_target = toward_target:normalizeInplace()
    self.Move:setMovementSettings(toward_target)]]
  end
end

function ET:getRenderPosition()
  local oy = self.Anim:getBaseImageOffset().y
  return math.floor((self.pos.y + oy) + 0.5)
end
  
return ET