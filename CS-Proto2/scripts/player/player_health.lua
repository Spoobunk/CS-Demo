vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"
Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

PlayerHealth = Object:extend()

function PlayerHealth:new(state_manager)
  self.state_manager = state_manager
  self.health = 300
  self.invincible = false
  -- timer instance only for things related to health
  self.health_timer = Timer.new()
end

function PlayerHealth:update(dt)
  self.health_timer:update(dt)
end

function PlayerHealth:isVulnerable()
  return self.state_manager.current_state.vulnerable and self.invincible == false
end

function PlayerHealth:takeDamage(separating_vector, other_collider)
  --if self.state_manager.current_state.vulnerable and self.invincible == false then 
     self.state_manager.player_components.move:Damaged_Knockback(vector(separating_vector.x, separating_vector.y))
     other_collider.object:collisionBounce(separating_vector)
  --end
end

return PlayerHealth