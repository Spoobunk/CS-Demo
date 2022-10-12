Object = require "libs.classic.classic"
Timer = require "libs.hump.timer"
vector = require "libs.hump.vector"

HealthBase = Object:extend()

function HealthBase:new(base_health, base_composure, main_class, anim_component, move_component)
  self.MAX_HEALTH = base_health
  self.health = base_health
  self.composure = base_composure
  self.main = main_class
  self.anim = anim_component
  self.move = move_component
  -- the variable that indicates whether another enemy hit by the same attack is being pushed into a wall, meaning this one should act the same.
  self.group_moving_into_wall = false
  self.pushed_enemy = nil
  
  self.last_attack_hitbox = nil
  self.timer = Timer.new()
end

function HealthBase:deductHealth(damage)
  self.health = self.health - damage
  self.composure = self.composure > 0 and self.composure - damage or self.composure
end

function HealthBase:canGetGrabbed()
  return self.composure <= 0
end

function HealthBase:dieCheck()
  if self.health <= 0 then self.main:changeStates('dying') end
end

function HealthBase:die()
  entity_manager:removeEntity(self.main)
end

function HealthBase:takePlayerDamage(seperating_vector, attack_collider)
  if self.last_attack_hitbox ~= attack_collider then
    --self.main:abortAttack()
    self.timer:clear()
    self.main:changeStates('hitstun')
    self:deductHealth(attack_collider.damage)
    self:dieCheck()
    self.main:cancelHeightTween()
    self.main.height = 0
    self.attack_signal = attack_collider.kb_signal
    self.attack_signal:emit('hit-confirm')
    --self.main.in_suspense = true
    self.attack_signal:register('suspense-end', function() self.main.in_suspense = false end)
    --self.main:setSuspense(attack_collider.suspense_time)

    self.last_attack_hitbox = attack_collider
    self.main.traveling_with_player = true
    self.group_moving_into_wall = false
    
    -- normalizes the knockback vector, then sets the x component to point directly away from the player, so the enemy never receives knockback toward the player
    seperating_vector:normalizeInplace()
    seperating_vector.x = -self.main.player_is_to
    self.timer:after(attack_collider.kb_wait, function() self:knockback(seperating_vector, attack_collider.knockback) self.main.traveling_with_player = false end)
    
    
    --self.attack_signal:register('pushed-against-wall', function(_, pushed_enemy) if self.main ~= pushed_enemy then self.pushed_enemy = pushed_enemy end end)
    
    --self.move:setMovementSettings(vector(0, 0), vector(0, 0), 0, 0, 0)
    
    -- if I need to apply knockback a little bit of time after the attack finishes, I just need to have the signal trigger a timer
    -- 
    self.attack_signal:register('attack-end', function(sit) 
      self.main.traveling_with_player = false
      if sit == 'aborted' then 
        self.timer:clear() self:knockback(seperating_vector, attack_collider.knockback) 
      else 
        self.move:setMovementSettings(vector(0, 0), vector(0, 0), 0, 0, 3000) 
      end 
    end)
  end
end

function HealthBase:takeDamage(seperating_vector, thrown_collider)
  if self.last_attack_hitbox ~= thrown_collider then
    
    self.last_attack_hitbox = thrown_collider
    ---self.main:abortAttack()
    self.timer:clear()
    --thrown_collider.object:setSuspense(thrown_collider.suspense)
    --thrown_collider.object:bounceOff(seperating_vector)
    thrown_collider.signal:emit('hit-confirm', seperating_vector, thrown_collider)
    print('strong velo: ' .. thrown_collider.object.Move.velocity:len())
    self.main:changeStates('hitstun')
    self:deductHealth(thrown_collider.damage)
    self:dieCheck()
    self.main:cancelHeightTween()
    self.main.height = 0
    self.main:setSuspense(thrown_collider.suspense)
    local thrown = thrown_collider.object
    -- knockback velocity = unit vector representing direction * magnitude of the thrown entity's velocity
    local knockback_velocity = seperating_vector:normalizeInplace() * (thrown.Move.velocity:len() * 0.75)
    self.move:setMovementSettings(vector(0, 0), knockback_velocity, 50, thrown.Move.friction, 3000)
    if self.main:currentStateIs('dying') then
      self.main:jump(0.4, 110, 'cubic', nil, 0.8)
      self.timer:after(0.7, function() self:die() end)
    else
      self.timer:after(0.5, function() self.move:defaultMovementSettings() self.main:changeStates('alerted') end)
    end
  end
end

-- called when a thrown entity collides with an enemy, but doesn't have enough speed to do damage, so it 'dinks' off.
function HealthBase:thrownDink(seperating_vector, thrown_collider)
  if self.last_attack_hitbox ~= thrown_collider then
    
    self.last_attack_hitbox = thrown_collider
    self.timer:clear()
    thrown_collider.signal:emit('dink-confirm', seperating_vector, thrown_collider)
    print('weak velo: ' .. thrown_collider.object.Move.velocity:len())
    local thrown = thrown_collider.object
    local knockback_velocity = seperating_vector:normalizeInplace() * (thrown.Move.velocity:len() * 0.75)
    --self.move:setMovementSettings(vector(0, 0), knockback_velocity, 50, thrown.Move.friction, 3000)
    self.move:setMovementSettings(nil, knockback_velocity, nil, nil, nil)
    --self.timer:after(0.25, function() self.move:defaultMovementSettings() end)
  end
end 

function HealthBase:playerAttackThrownReflect(separating_vector, thrown_collider)
  if self.last_attack_hitbox ~= thrown_collider then
    self.last_attack_hitbox = thrown_collider
    print('lol')
    local deflect_vel = separating_vector:normalized() 
    deflect_vel.x = -self.main.player_is_to
    
    deflect_vel = deflect_vel * self.main.Move.velocity:len() * 2
    
    self.main.Move:setMovementSettings(nil, deflect_vel, nil, nil, nil)
  end
end

function HealthBase:knockback(knockback_dir, knockback_power)
  -- removes the attack-end signal. This stops the function that normally runs whenever the player's attack ends, only if the enemy has already experienced knockback.
  -- for situations where knockback is applied after the attack ends (the enemy 'hangs in the air' for a moment) this does nothing.
  -- for situations where knockback is applied before the attack ends, this prevents the enemy's momentum from being killed when the player's attack ends.
  self.attack_signal:clear('attack-end')
  self.move:setMovementSettings(vector(0, 0), knockback_dir * knockback_power, 50, 0.55, 3000)
  self.group_moving_into_wall = false
  self.pushed_enemy = nil
  if self.main:currentStateIs('dying') then
    self.main:jump(0.4, 110, 'cubic', nil, 1)
    self.timer:after(0.7, function() self:die() end)
  else
    self.timer:after(0.5, function() self.move:defaultMovementSettings() self.main:changeStates('alerted') end)
  end
end  

function HealthBase:update(dt)
  if not self.main.in_suspense then self.timer:update(dt) end

  if self.main.moving_into_wall_x then self.attack_signal:emit('pushed-against-wall', math.abs(self.main.player.pos.x - self.main.pos.x), self.main) end
end


return HealthBase 