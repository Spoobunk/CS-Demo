Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

AnimComponent = require "scripts.entities.entity_anim_base"
MoveComponent = require "scripts.entities.entity_move_base"

basic_attack = require "scripts.entities.enemies.attack procedures.attack_basic"

Enemy = require "scripts.entities.enemies.enemy_base"

ET = Enemy:extend()
ET.state = {
  idle = {
    enter = function(self) 
      self.Anim:switchAnimation('idle')
      self.facing_player = false
      self.Move:defaultMovementSettings() 
      self.following_player = false
      for i,c in ipairs(self.colliders) do
        if c.tag == "Test" then
          self.collision_world:remove(c)
          table.remove(self.colliders, i)
        end
      end
    end,
    vulnerable = true
  },
  alerted = {
    enter = function(self) 
      self.Anim:switchAnimation('walk')
      self.facing_player = true
      self.Move:defaultMovementSettings() 
      self.following_player = true
      for i,c in ipairs(self.colliders) do
        if c.tag == "Test" then
          self.collision_world:remove(c)
          table.remove(self.colliders, i)
        end
      end
    end,
    vulnerable = true
  },
  attacking = {
    enter = function(self) 

    end,
    vulnerable = true
  },
  hitstun = {
    
  },
}

ET.attacks = {
    basic = basic_attack
}
function ET:new(x, y, collision_world, tile_world)
  ET.super.new(self, x, y, collision_world, tile_world)
  self.state = ET.state.idle
  self.current_attack = nil
  
  --Anim setup
  local et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  self.base_image_offset = vector(math.floor(47 / 2), 23)
  self.Anim = AnimComponent(self.base_image_offset.x, self.base_image_offset.y, et_sheet)
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
  
  self:addCollider(self.collision_world:circle(self.pos.x, self.pos.y, 100), "Enemy", self, function() return self.pos:unpack() end) 
  
  -- this is set when the enemy is alerted to the player
  self.trigger_attack_area = nil
  
  
  -- How this works: the collision resolution table specifies how to resolve collisions between colliders with certain tags. When a collider attached to this object collides with something, it goes here to look for how to resolve it, using the tag of the collided object.
  self.collision_resolution = {
    Enemy = {Player = function() self:alertedToPlayer() end,
              Attack_Trigger = function() self:getInAttackPosition() end,
              Player_Attack = function() self:abortAttack() end,
              Testy = function(separating) normal = vector(separating.x, separating.y) self.Move:setMovementSettings(normal / 2) end}
  }
  
  self.following_player = false
  self.facing_player = true
  
  --self.tile_world = tile_world
  -- the the x, y coords of the tile_collider relative to the enemy's pos
  --self.tile_collider_offset = vector(10, 0)
  -- sets up the tile collider
  --self.tile_collider = self.tile_world:add(self, self.pos.x - self.tile_collider_offset.x, self.pos.y - self.tile_collider_offset.y, 25, 24)
  self:setUpTileCollider(self.pos.x, self.pos.y, 10, 0, 25, 24)
end

function ET:update(dt)
  
  self.Anim:update(dt)
  self.Move:update(dt)
  if(self.current_attack) then
    self.current_attack:update(dt)
  end
  --[[
  local move_step = self.Move:getMovementStep(dt)
  local goal_pos = (self.ground_pos + move_step) - self.tile_collider_offset
  local actualX, actualY, cols, len = self.tile_world:move(self, goal_pos.x, goal_pos.y)
  self.ground_pos = vector(actualX, actualY) + self.tile_collider_offset
  ]]
  --self.ground_pos = self.ground_pos + self.Move:getMovementStep(dt)
  --self.pos = self.ground_pos - vector(0, self.height)
  
  
  if(self.player and self.state == ET.state.alerted) then
    self.Move:setMovementSettings(self.toward_player)
    --self.pos = self.pos + (self.toward_player * self.speed) * (1+dt)
  end
  
  if(self.player and self.facing_player) then
    self.Anim:flipSpriteHorizontal(self.player_is_to)
  end
  
  --self.player_was_to = self.player_is_to
  -- the update function of the superclasses has to come after updating the attack, otherwise the height variable will be all off.
  ET.super.update(self, dt)
end

function ET:draw()
  self.Anim:draw(self.pos.x, self.pos.y)
  love.graphics.setColor(1, 0, 0, 1)
  --love.graphics.rectangle('line', self.pos.x, self.pos.y, self.Anim:getCurrentAnim():getDimensions())
  love.graphics.points(self.pos:unpack())

  self:drawColliders()
  self:drawTileCollider()
  love.graphics.line(self.pos.x - 30, self:getRenderPosition(), self.pos.x + 30, self:getRenderPosition())
  love.graphics.setColor(1, 1, 1, 1)
end

function ET:alertedToPlayer()
  if(self.state == ET.state.idle) then
    self.state = ET.state.alerted
    self.Anim:switchAnimation('walk')
    local trigger_attack_area = self.collision_world:circle(self.player.position.x, self.player.position.y, 20)
    self:addCollider(trigger_attack_area, "Attack_Trigger", self, function() return self.player.position:unpack() end)
    self.following_player = true
  end
end

function ET:getInAttackPosition()
  if(self.state == ET.state.alerted) then
    self.state = ET.state.attacking
    self.current_attack = basic_attack(self)
    --self.Anim:flipSpriteHorizontal(self.player_is_to)
    --[[self.following_player = false
    local target = vector(self.player.position.x + 10, self.player.position.y)
    local toward_target = target - self.pos
    toward_target = toward_target:normalizeInplace()
    self.Move:setMovementSettings(toward_target)]]
  end
end

function ET:abortAttack()
  if(self.current_attack) then
    self.current_attack:exit()
  end
end

function ET:changeStates(to_state)
  self.state = ET.state[to_state]
  ET.state.alerted.enter(self)
end
--[[
function ET:getRenderPosition()
  --local oy = self.Anim:getBaseImageOffset().y
  local oy = self.base_image_offset.y
  return math.floor(((self.pos.y + self.height) + oy) + 0.5)
end
]]
return ET