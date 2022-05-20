Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

Entity = require "scripts.entities.entity_base"

EnemyBase = Entity:extend()

-- specific enemy classes should call this through the super keyword
function EnemyBase:new(x, y, collision_world, tile_world) 
  EnemyBase.super.new(self, x, y, collision_world, tile_world)
  self.toward_player = vector(0, 0)
  self.player = nil
  self.player_is_to = nil
end

function EnemyBase:update(dt)
  local collisions = self.collision_world:collisions(self.colliders[1])
  for other, separating_vector in pairs(collisions) do
    if(not self.player and other.tag == "Player") then
      self.player = other.object
    end
    if(self.collision_resolution[other.tag]) then
      self.collision_resolution[other.tag]()
    end
  end
  
  -- finds vector pointing towards player
  if self.player then self.toward_player = self.player.position - self.pos self.toward_player:normalizeInplace() end
  
  -- updates the variable telling whether is to the right or left of the enemy
  if self.player then
    if self.player.position.x > self.pos.x then self.player_is_to = 1 else self.player_is_to = -1 end
  end
  
  EnemyBase.super.update(self, dt)
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