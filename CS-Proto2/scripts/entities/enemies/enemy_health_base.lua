Object = require "libs.classic.classic"
Timer = require "libs.hump.timer"
vector = require "libs.hump.vector"

HealthBase = Object:extend()

function HealthBase:new(base_health, main_class, anim_component, move_component)
  self.health = base_health
  self.main = main_class
  self.anim = anim_component
  self.move = move_component
  -- the variable that indicates whether another enemy hit by the same attack is being pushed into a wall, meaning this one should act the same.
  self.group_moving_into_wall = false
  self.pushed_enemy = nil
  
  self.last_attack_hitbox = nil
  self.timer = Timer.new()
end

-- need to change this so the trigger knockback signal is emitted every time a stage of the smash attack ends, but getting hit by another attack cancels any knockback before it occurs
function HealthBase:takePlayerDamage(seperating_vector, attack_collider)
  if self.last_attack_hitbox ~= attack_collider then
    self.main:abortAttack()
    self.timer:clear()
    self.main:changeStates('hitstun')

    self.last_attack_hitbox = attack_collider
    self.main.traveling_with_player = true
    self.group_moving_into_wall = false
    
    -- normalizes the knockback vector, then sets the x component to point directly away from the player, so the enemy never receives knockback toward the player
    seperating_vector:normalizeInplace()
    seperating_vector.x = -self.main.player_is_to
    self.timer:after(attack_collider.kb_wait, function() self:knockback(seperating_vector, attack_collider.knockback) self.main.traveling_with_player = false end)
    
    self.attack_signal = attack_collider.kb_signal
    --self.attack_signal:register('pushed-against-wall', function(_, pushed_enemy) if self.main ~= pushed_enemy then self.pushed_enemy = pushed_enemy end end)
    
    --self.move:setMovementSettings(vector(0, 0), vector(0, 0), 0, 0, 0)
    
    -- if I need to apply knockback a little bit of time after the attack finishes, I just need to have the signal trigger a timer
    -- 
    self.attack_signal:register('attack-end', function(sit) 
      self.main.traveling_with_player = false
      if sit == 'aborted' then 
        self.timer:clear() self:knockback(seperating_vector, attack_collider.knockback) 
        print('flooly')
      else 
        self.move:setMovementSettings(vector(0, 0), vector(0, 0), 0, 0, 3000) 
      end 
    end)
  end
end

function HealthBase:takeDamage(seperating_vector, thrown_collider)
  if self.last_attack_hitbox ~= thrown_collider then
    self.last_attack_hitbox = thrown_collider
    self.main:abortAttack()
    self.timer:clear()
    thrown_collider.object:bounceOff(seperating_vector)
    self.main:changeStates('hitstun')
    -- knockback velocity = unit vector representing direction * magnitude of the thrown entity's velocity
    local knockback_velocity = seperating_vector:normalizeInplace() * (thrown_collider.object.Move.velocity:len() * 0.75)
    self.move:setMovementSettings(vector(0, 0), knockback_velocity, 50, 0.55, 3000)
    self.timer:after(0.5, function() self.move:defaultMovementSettings() self.main:changeStates('alerted') end)
  end
end

function HealthBase:knockback(knockback_dir, knockback_power)
  -- removes the attack-end signal. This stops the function that normally runs whenever the player's attack ends, only if the enemy has already experienced knockback.
  -- for situations where knockback is applied after the attack ends (the enemy 'hangs in the air' for a moment) this does nothing.
  -- for situations where knockback is applied before the attack ends, this prevents the enemy's momentum from being killed when the player's attack ends.
  self.attack_signal:clear('attack-end')
  self.move:setMovementSettings(vector(0, 0), knockback_dir * knockback_power, 50, 0.55, 3000)
  self.timer:after(0.5, function() self.move:defaultMovementSettings() self.main:changeStates('alerted') end)
  self.group_moving_into_wall = false
  self.pushed_enemy = nil
end  

function HealthBase:update(dt)
  self.timer:update(dt)
  if(self.traveling_with_player) then 
    --local good_vel = vector(math.floor(self.main.player.player_components.move:getVelocity().x + 0.5), math.floor(self.main.player.player_components.move:getVelocity().y + 0.5))
    --self.move:setMovementSettings(vector(0, 0), self.main.player.player_components.move:getVelocity(), 0, 0, 100000000)
    --self.move:setMovementSettings(vector(0, 0), good_vel, 0, 0, 100000000)
    --self.main.pos = self.main.player.position + self.relative_pos
    --print(self.main.player.position.x - self.main.pos.x)
  end
  
  if self.main.moving_into_wall_x then self.attack_signal:emit('pushed-against-wall', math.abs(self.main.player.pos.x - self.main.pos.x), self.main) end
  --if self.pushed_enemy then self.group_moving_into_wall = self.pushed_enemy.traveling_with_player end
end


return HealthBase 