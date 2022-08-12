Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

Grabbable = require "scripts.entities.entity_grabbable_base"

utilities = require 'scripts.utilities'

EnemyBase = Grabbable:extend()

EnemyBase.state = {
  idle = {
    name = 'idle',
    enter = nil,
    exit = nil,
    vulnerable = true
  },
  alerted = {
    name = 'alerted',
    enter = nil,
    exit = nil,
    vulnerable = true
  },
  attacking = {
    name = 'attacking',
    enter = nil,
    exit = nil,
    vulnerable = true
  },
  hitstun = {
    name = 'hitstun',
    enter = nil,
    exit = nil,
    vulnerable = false
  },
  grabbed = {
    name = 'grabbed',
    enter = nil,
    exit = nil,
    vulnerable = false
  },
  thrown = {
    name = 'thrown',
    enter = nil,
    exit = nil,
    vulnerable = false
  },
}

-- specific enemy classes should call this through the super keyword
function EnemyBase:new(x, y, collision_world, tile_world) 
  EnemyBase.super.new(self, x, y, collision_world, tile_world, 'Enemy')
  self.toward_player = vector(0, 0)
  self.player = nil
  self.player_is_to = nil
  self.traveling_with_player = false
  -- the variable that indicates whether an enemy is running into a wall horizontally or not
  self.moving_into_wall_x = false
  
  -- defult collision resolution for enemies
  self:setCollisionResolution('Enemy', 'PlayerAttack', function(separating_vector, other) self.Health:takePlayerDamage(vector(separating_vector.x, separating_vector.y), other) end)
  self:setCollisionResolution('Enemy', 'PlayerThrown', function(separating_vector, other) 
    -- so the enemy doesn't collide with its own thrown collider
    if other.object ~= self then 
      -- going to update this so that thrown enemies only do damage when going above a certain speed
      if other.object.Move.velocity:len() > 0 then
        self.Health:takeDamage(vector(separating_vector.x, separating_vector.y), other) 
      end
    end end)
  --[[
  self:setCollisionResolution('PlayerThrown', 'Enemy', function(separating_vector, other)
    if other.object ~= self then 
      self:bounceOff(vector(separating_vector.x, separating_vector.y)) 
      print('dsdad')
    end end)
    ]]
  self:setCollisionResolution('Enemy', 'Test', function(separating_vector) self:moveTo(self.ground_pos + vector(separating_vector.x, separating_vector.y)) end)
  self:setCollisionResolution('Enemy', 'Enemy', function(separating_vector, other) self:enemyOnEnemyCollision(separating_vector, other) end)
  --[[
  self.collision_resolution.Enemy = {
    PlayerAttack = function(separating_vector, other) self.Health:takeDamage(vector(separating_vector.x, separating_vector.y), other) end, 
    Test = function(separating_vector) self:moveTo(self.ground_pos + vector(separating_vector.x, separating_vector.y)) end, 
    Enemy = function(separating_vector, other) self:enemyOnEnemyCollision(separating_vector, other) end
  }
  ]]
  self:setCollisionCondition('Enemy', 'Enemy', function() return self.state ~= ET.state.hitstun and self.state ~= ET.state.thrown end)
  -- The player checks that the enemy isn't in hitstun state in its collisions response
  self:setCollisionCondition('Enemy', 'Player', function() return self.state ~= ET.state.thrown end)
end

function EnemyBase:update(dt)
  if(not self.player) then
    for _,c in ipairs(self.colliders) do
      local collisions = self.collision_world:collisions(c)
      for other, separating_vector in pairs(collisions) do
        if(other.tag == "Player" or other.tag == "PlayerAttack") then
          self.player = other.object
        end
      end
    end
  end
  
  -- finds vector pointing towards player
  if self.player then self.toward_player = self.player.position - self.pos self.toward_player:normalizeInplace() end
  
  -- updates the variable telling whether is to the right or left of the enemy
  if self.player then
    if self.player.position.x > self.pos.x then self.player_is_to = 1 else self.player_is_to = -1 end
  end
  
  self.moving_into_wall_x = false  
  if self.player and self.traveling_with_player then 
    --print(self.moving_into_wall_x)
    local test_pos = vector(self.ground_pos.x + (-1 * self.player_is_to), self.ground_pos.y)
    self.moving_into_wall_x = self:checkTileCollision(test_pos) or self:checkEntityCollision(self.hitbox, test_pos)
    
    --if self.Health.group_moving_into_wall then self.moving_into_wall_x = true end
    
    --print(self.ground_pos.x .. '-' .. self.ground_pos.x + (-1 * self.player_is_to))
    --if (self.moving_into_wall_x and utilities.sign(self.player.current_movestep.x) == self.player_is_to) then
    if (self.moving_into_wall_x) then
      self:updateMovement(dt, vector(0, 0))
      --self:updateMovement(dt, vector(0, self.player.current_movestep.y))
      --print(utilities.sign(self.player.current_movestep.x) == self.player_is_to)
      --print('fun')
    else
      --print('bug')
      self:updateMovement(dt, self.player.current_movestep) 
    end
  else 
    if self:currentStateIs('grabbed') then self:updateMovement(dt, self.player.current_movestep) else self:updateMovement(dt, self.Move:getMovementStep(dt)) end
  end
  
  if self.thrown then 
    if self.Move.velocity <= vector(50, 50) and self.Move.velocity >= vector(-50, -50) then 
      self:finishThrow()
    end
  end
  --self:updateMovement(dt, self.Move:getMovementStep(dt))
  --EnemyBase.super.update(self, dt)
end

function EnemyBase:getGrabbed(grab_collider)
  self:changeStates('grabbed')
  EnemyBase.super.getGrabbed(self, grab_collider)
end

function EnemyBase:getThrown(throw_dir)
  self:changeStates('thrown')
  EnemyBase.super.getThrown(self, throw_dir)
end

function EnemyBase:finishThrow()
  self:changeStates('alerted')
  EnemyBase.super.finishThrow(self)
end

function EnemyBase:changeStates(to_state)
  -- calls the exit method on the last state if one is provided
  if self.state.exit then self.state.exit(self) end
  self.state = ET.state[to_state]
  if self.state.enter then self.state.enter(self) end
end

function EnemyBase:currentStateIs(is_state)
  return self.state == ET.state[is_state] 
end

function EnemyBase:getCurrentState()
  return self.state.name
end

-- collision response function for when an enemy collides with another enemy (only works for collisions between test enemies right now)
function EnemyBase:enemyOnEnemyCollision(separating_vector, other) 
  --if (self.state ~= ET.state.hitstun and other.object.state ~= ET.state.hitstun) then 
  self:moveTo(self.pos + vector(separating_vector.x, separating_vector.y)) 
    --other.object:moveTo(other.object.pos - vector(separating_vector.x, separating_vector.y)/2) 
  --end 
end

function EnemyBase:collisionBounce(reverse_seperating_vector)
  local knockback_dir = vector(-reverse_seperating_vector.x, -reverse_seperating_vector.y):normalizeInplace() 
  self.Move:setMovementSettings(nil, knockback_dir * 11120, nil, nil, nil)
end
  
--[[
function enemy_base:addCollider(collider, tag, object, position_function)
  collider.tag = tag
  collider.object = object
  collider.position_function = position_function 
  table.insert(self.colliders, collider)
  return collider
end

function enemy_base:updateColliderPositions()
  for _,c in ipairs(self.colliders) do
    c:moveTo(c.position_function())
  end
end

function enemy_base:drawColliders()
  for _,c in ipairs(self.colliders) do
    c:draw()
  end
end
]]
function EnemyBase:GetRenderPosition()
  error('subclasses should override EnemyBase\'s getRenderPosition() function')
end

return EnemyBase