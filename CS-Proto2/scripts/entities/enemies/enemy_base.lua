Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

Entity = require "scripts.entities.entity_base"

enemy_base = Entity:extend()

-- specific enemy classes should call this through the super keyword
function enemy_base:new(x, y, collision_world) 
  self.pos = vector(x, y)
  -- variable represeting the position of the object on the ground, regardless of the height they are drawn at
  self.ground_pos = self.pos
  -- variable added to the y-position, representing the height of the object
  self.height = 0
  self.toward_player = vector(0, 0)
  self.collision_world = collision_world
  self.colliders = {}
  self.player = nil
  self.player_is_to = nil
end

function enemy_base:alertedToPlayer()
  print("to be implemented by specific enemy classes")
end

function enemy_base:update(dt)
  local collisions = self.collision_world:collisions(self.colliders[1])
  for other, separating_vector in pairs(collisions) do
    if(not self.player and other.tag == "Player") then
      self.player = other.object
    end
    if(self.collision_resolution[other.tag]) then
      self.collision_resolution[other.tag]()
    end
  end
  
  self:updateColliderPositions()
  
  -- finds vector pointing towards player
  if self.player then self.toward_player = self.player.position - self.pos self.toward_player:normalizeInplace() end
  -- updates the variable telling whether is to the right or left of the enemy
  if self.player then
    if self.player.position.x > self.pos.x then self.player_is_to = 1 else self.player_is_to = -1 end
  end
end

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

function enemy_base:GetRenderPosition()
  error('subclasses should override enemy_base\'s getRenderPosition() function')
end

return enemy_base