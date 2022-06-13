Object = require "libs.classic.classic"
Timer = require "libs.hump.timer"
vector = require "libs.hump.vector"

HealthBase = Object:extend()

function HealthBase:new(base_health, main_class, anim_component, move_component)
  self.health = base_health
  self.main = main_class
  self.anim = anim_component
  self.move = move_component
  self.timer = Timer.new()
end

function HealthBase:takeDamage(seperating_vector, attack_collider)
  self.main:changeStates('hitstun')
  self:knockback(seperating_vector)
end

function HealthBase:knockback(knockback_dir)
  knockback_dir:normalizeInplace()
  self.move:setMovementSettings(vector(0, 0), knockback_dir * 1700, 50, 0.55, 3000)
  self.timer:after(0.5, function() self.move:defaultMovementSettings() self.main:changeStates('alerted') end)
end  

function HealthBase:update(dt)
  self.timer:update(dt)
end


return HealthBase