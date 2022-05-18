Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

Entity = require "scripts.entities.entity_base"

enemy_base = Entity:extend()

-- specific enemy classes should call this through the super keyword
function enemy_base:new(x, y, collision_world) 
  self.pos = vector(x, y)
  self.toward_player = vector(0, 0)
  self.collision_world = collision_world
  self.player = nil
end

function enemy_base:alertedToPlayer()
  print("to be implemented by specific enemy classes")
end

function enemy_base:update(dt)
  local collisions = self.collision_world:collisions(self.collider)
  for other, separating_vector in pairs(collisions) do
    if(not self.player and other.tag == "Player") then
      self.player = other.object
      self:alertedToPlayer()
    end
  end
  
  if self.player then self.toward_player = self.player.position - self.pos end
end

function enemy_base:GetRenderPosition()
  error('subclasses should override enemy_base\'s getRenderPosition() function')
end

return enemy_base