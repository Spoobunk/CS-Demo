vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"
Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

PlayerAttack = Object:extend()

local path_to_attacks = "scripts.player.player attacks."
PlayerAttack.attacks = {
  mash = require (path_to_attacks .. 'player_attack_mash'),
}

--good settings: acc = 200, friction = 0.9, maxvel = 600
function PlayerAttack:new(state_manager)
  self.state_manager = state_manager
  self.current_attack = nil
end

function PlayerAttack:update(dt)
  if self.current_attack then self.current_attack:update(dt) end
end

-- adds a regular collider, then adds all elements needed for an attack hitbox
-- @param power: damage inflicted on the enemy
-- @param knockback: knockback inflicted on the enemy
-- @param kb_signal: a hump signal object that enemies can register functions so they know when to experience knockback
-- @param kb_wait: the amount of time before knockback is applied to the enemy
function PlayerAttack:addAttackHitbox(collider, tag, position_function, power, knockback, kb_signal, kb_wait)
  local hitbox = self.state_manager:addCollider(collider, tag, self.state_manager, position_function) 
  hitbox.power = power
  hitbox.knockback = knockback
  hitbox.kb_signal = kb_signal
  hitbox.kb_wait = kb_wait
  return hitbox
end

function PlayerAttack:attackInput()
  if self.current_attack then self.current_attack:attackInput() end
end

function PlayerAttack:exit()
  self.state_manager:change_states('idle')
  self.current_attack = nil
end

function PlayerAttack:startMashAttack()
  self.current_attack = PlayerAttack.attacks.mash(self)
  self.state_manager:change_states('attacking')
end

return PlayerAttack