Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

utilities = require "scripts.utilities"
shader_assembler = require 'scripts.shader_wrapper'

AnimComponent = require "scripts.entities.entity_anim_base"
MoveComponent = require "scripts.entities.entity_move_base"
HealthComponent = require "scripts.entities.enemies.enemy_health_base"

basic_attack = require "scripts.entities.enemies.attack procedures.attack_basic"

ShadowObject = require "scripts.entities.effects.entity_shadow"

Enemy = require "scripts.entities.enemies.enemy_base"

ET = Enemy:extend()


ET.state = utilities.deepCopy(ET.super.state)

ET.state.idle.enter = function(self) 
  self.Anim:switchAnimation('idle')
  self.facing_quarry = false
  self.Move:defaultMovementSettings() 
  self.following_quarry = false
end

ET.state.alerted.enter = function(self)
  self.Anim:switchAnimation('walk')
  self.facing_quarry = true
  self.Move:defaultMovementSettings() 
  self.following_quarry = true
end

ET.state.hitstun.enter = function(self) 
  self.Anim:switchAnimation('idle')
  if self.quarry then self.Anim:flipSpriteHorizontal(self.quarry_is_to) end
end

ET.state.attacking.enter = function(self) end
ET.state.attacking.exit = function(self)
  self.abortAttack(self)
end

ET.state.thrown.exit = function(self) end

ET.state.grabbed.enter = function(self) --[[self.Anim:switchAnimation('idle') self.Anim.current_anim:pause()]] end

ET.attacks = {
    basic = basic_attack
}
function ET:new(x, y, collision_world, tile_world)
  ET.super.new(self, x, y, 16, collision_world, tile_world)
  self.name = 'test enemy'
  self.state = ET.state.idle
  self.current_attack = nil
  
  --Anim setup
  local et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  self.Anim = AnimComponent(self, 'assets/basic/sprites/devout/', 'devout')
  local walk_grid = self.Anim:createGrid('step')
  local idle_grid = self.Anim:createGrid('idle')
  local windup_grid= self.Anim:createGrid('wind up')
  local attack_grid = self.Anim:createGrid('spin')
  self.Anim:addAnimation('walk', anim8.newAnimation(walk_grid('1-2', 1, '1-2', 2), .1), 75, 26)
  self.Anim:addAnimation('idle', anim8.newAnimation(idle_grid('1-2', 1), .5), 77, 23)
  self.Anim:addAnimation('attack_windup', anim8.newAnimation(windup_grid(2, 1), 1, 'pauseAtEnd'), 75, 21)
  self.Anim:addAnimation('attack', anim8.newAnimation(attack_grid('1-2', 1, '1-2', 2), .1), 49, 50)
  
  -- super slippery movement
  --self.Move = MoveComponent(50, 0.15, 1200)
  self.Move = MoveComponent(4, 0.09, 150)
  self.Health = HealthComponent(900, 0, self, self.Anim, self.Move)
  
  self.hitbox = self:addAttackCollider(self.collision_world:circle(self.pos.x, self.pos.y, 20), "Enemy", function() return self.ground_pos.x, self.ground_pos.y - self.base_height end, 3, 0.5, 1500) 
  self.alert_trigger_area = self:addCollider(self.collision_world:circle(self.pos.x, self.pos.y, 200), "AlertTrigger", self, function() return self.ground_pos:unpack() end) 
  
  -- this is set when the enemy is alerted to the player
  self.attack_trigger_area = nil
  
  -- How this works: the collision resolution table specifies how to resolve collisions between colliders with certain tags. When a collider attached to this object collides with something, it goes here to look for how to resolve it, using the tag of the collided object.
  self:setCollisionResolution('AlertTrigger', 'Player', function() if (self.state == ET.state.idle) then self:alertedToPlayer() end end)
  self:setCollisionResolution('AttackTrigger', 'Player', function() if (self.state == ET.state.alerted) then self:getInAttackPosition() end end)
  
  self.following_quarry = false
  self.facing_quarry = true
  
  self:setUpTileCollider(10, 0, 20, 18)
  
  self.shadow_object = ShadowObject(self, 15, 7)
end

-- function run every time the enemy is thrown, creating a thrown collider for the enemy
function ET:instanceThrownCollider()
  self.thrown_hitbox = self:addThrownCollider(self.collision_world:circle(self.pos.x, self.pos.y, 40), function() return self.ground_pos.x, self.ground_pos.y - self.base_height end, 50, 0.2)
end

function ET:update(dt)
  
  if not self.in_suspense then
    self.Anim:update(dt)
    self.Move:update(dt)
    
  end
  self.Health:update(dt)
  
  if(self.current_attack) then
    if not self.in_suspense then self.current_attack:update(dt) end
  end
  
  if(self.quarry and self.state == ET.state.alerted) then
    self.Move:setMovementSettings(self.toward_quarry)
  end
  
  if(self.quarry and self.facing_quarry) then
    self.Anim:flipSpriteHorizontal(self.quarry_is_to)
  end
  
  ET.super.update(self, dt)
end

function ET:alertedToPlayer()
  if(self.state == ET.state.idle) then
    self.state = ET.state.alerted
    self.Anim:switchAnimation('walk')
    self:removeCollider(self.alert_trigger_area)
    local attack_trigger_area = self.collision_world:circle(self.pos.x, self.pos.y, 200)
    self:addCollider(attack_trigger_area, "AttackTrigger", self, function() return self.ground_pos.x, self.ground_pos.y - self.base_height end)
    self.following_quarry = true
  end
end

function ET:getInAttackPosition()
  if(self.state == ET.state.alerted) then
    self.state = ET.state.attacking
    self.current_attack = basic_attack(self)
  end
end

function ET:abortAttack()
  if(self.current_attack) then
    self.current_attack:exit()
  end
end



return ET