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
  local last_state = self.state_manager:Get_Current_State()
  self.state_manager:change_states('hitstun')
  local damage = other_collider.damage
  local suspense = other_collider.suspense or damage * 0.01
  local knockback = other_collider.knockback or damage * 1000
  self.state_manager.camera:setTarget(vector(0.001, 0.001))
  self.state_manager.player_components.move:Damaged_Knockback(vector(separating_vector.x, separating_vector.y), knockback)
  self.state_manager.player_components.grab:abortGrab(suspense, last_state)
  self.state_manager:setSuspense(suspense, false)
  if other_collider.tag == 'Enemy' then other_collider.object:collisionBounce(separating_vector, suspense) end
end

--this method is useful for when the player should take damage 'on-command', rather than as the result of any collision
function PlayerHealth:takeDirectDamage(damage, sus, kb_pow, knockback_dir)
  if not self:isVulnerable() then return false end
  local last_state = self.state_manager:Get_Current_State()
  self.state_manager:change_states('hitstun')
  local suspense = sus or damage * 0.01
  local knockback_pow = kb_pow or damage * 1000
  self.state_manager.player_components.move:Damaged_Knockback(knockback_dir, knockback_pow)
  self.state_manager.player_components.grab:abortGrab(suspense, last_state)
  self.state_manager:setSuspense(suspense, false)
end

return PlayerHealth