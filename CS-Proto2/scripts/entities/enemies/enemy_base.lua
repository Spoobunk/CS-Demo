Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

Entity = require "scripts.entities.entity_base"

utilities = require 'scripts.utilities'

EnemyBase = Entity:extend()

-- specific enemy classes should call this through the super keyword
function EnemyBase:new(x, y, collision_world, tile_world) 
  EnemyBase.super.new(self, x, y, collision_world, tile_world)
  self.toward_player = vector(0, 0)
  self.player = nil
  self.player_is_to = nil
  self.traveling_with_player = false
  -- the variable that indicates whether an enemy is running into a wall horizontally or not
  self.moving_into_wall_x = false
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
    if (self.moving_into_wall_x and utilities.sign(self.player.current_movestep.x) == self.player_is_to) then
      self:updateMovement(dt, vector(0, self.player.current_movestep.y))
      --print(utilities.sign(self.player.current_movestep.x) == self.player_is_to)
      --print('fun')
    else
      --print('bug')
      self:updateMovement(dt, self.player.current_movestep) 
    end
  else 
    self:updateMovement(dt, self.Move:getMovementStep(dt)) 
  end
  --self:updateMovement(dt, self.Move:getMovementStep(dt))
  --EnemyBase.super.update(self, dt)
end

-- collision response function for when an enemy collides with another enemy (only works for collisions between test enemies right now)
function EnemyBase:enemyOnEnemyCollision(separating_vector, other) 
  if (self.state ~= ET.state.hitstun and other.object.state ~= ET.state.hitstun) then 
    self:moveTo(self.pos + vector(separating_vector.x, separating_vector.y)/2) 
    other.object:moveTo(other.object.pos - vector(separating_vector.x, separating_vector.y)/2) 
  end 
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