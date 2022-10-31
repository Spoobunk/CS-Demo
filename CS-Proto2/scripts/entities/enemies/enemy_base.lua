Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"

Grabbable = require "scripts.entities.entity_grabbable_base"

utilities = require 'scripts.utilities'

EnemyBase = Grabbable:extend()

EnemyBase.state = {
  idle = {
    name = 'idle',
    enter = nil,
    exit = nil,
    vulnerable = true
  },
  alerted = {
    name = 'alerted',
    enter = nil,
    exit = nil,
    vulnerable = true
  },
  attacking = {
    name = 'attacking',
    enter = nil,
    exit = nil,
    vulnerable = true
  },
  hitstun = {
    name = 'hitstun',
    enter = nil,
    exit = nil,
    vulnerable = true
  },
  grabbed = {
    name = 'grabbed',
    enter = nil,
    exit = nil,
    vulnerable = false
  },
  thrown = {
    name = 'thrown',
    enter = nil,
    exit = nil,
    vulnerable = false
  },
  dying = {
    name = 'dying',
    enter = nil,
    exit = nil,
    vulnerable = false
  },
}

-- specific enemy classes should call this through the super keyword
function EnemyBase:new(x, y, collision_world, tile_world) 
  -- runs the constructer of Grabbable base class, with the last argument being the name of the main hitbox of the object, the one that is hit by a grab
  EnemyBase.super.new(self, x, y, collision_world, tile_world, 'Enemy')
  self.toward_player = vector(0, 0)
  self.player = nil
  self.player_is_to = nil
  self.traveling_with_player = false
  -- the variable that indicates whether an enemy is running into a wall horizontally or not
  self.moving_into_wall_x = false
  
  self.main_timer = Timer.new()
  -- a timer only for keeping track of when the enemy breaks out of a grab. this is its own timer so that it can be 'paused' whenever the timer shouldn't be advancing; such as when the player is spinning or attacking
  self.grab_breakout_timer = Timer.new()
  -- bool controlling whether the breakout timer is updated; it's set by the player in PlayerGrab:update()
  self.update_breakout_timer = false
  
  -- defult collision resolution for enemies
  self:setCollisionResolution('Enemy', 'PlayerAttack', function(separating_vector, other) 
      if self:currentStateIs('thrown') then 
        self.Health:playerAttackThrownReflect(vector(separating_vector.x, separating_vector.y), other)
      else
        self.Health:takePlayerDamage(vector(separating_vector.x, separating_vector.y), other) 
      end end)
  self:setCollisionResolution('Enemy', 'PlayerThrown', function(separating_vector, other) 
    -- so the enemy doesn't collide with its own thrown collider
    if other.object ~= self and not self.thrown then 
      -- going to update this so that thrown enemies only do damage when going above a certain speed
      if other.object.Move.velocity:len() > 500 then
        self.Health:takeDamage(vector(separating_vector.x, separating_vector.y), other) 
      else
        self.Health:thrownDink(vector(separating_vector.x, separating_vector.y), other)
      end
    end end)

  self:setCollisionResolution('Enemy', 'Test', function(separating_vector) self:moveTo(self.ground_pos + vector(separating_vector.x, separating_vector.y)) end)
  self:setCollisionResolution('Enemy', 'Enemy', function(separating_vector, other) self:enemyOnEnemyCollision(separating_vector, other) end)

  self:setCollisionCondition('Enemy', 'Enemy', function() return not(self:currentStateIs('hitstun') or self:currentStateIs('thrown') or self:currentStateIs('dying'))  end)
  -- The player checks that the enemy isn't in hitstun state in its collisions response
  self:setCollisionCondition('Enemy', 'Player', function() return not(self:currentStateIs('thrown') or self:currentStateIs('dying')) end)
  self:setCollisionCondition('Enemy', 'PlayerAttack', function() return not(self.in_suspense) end)
end

-- EnemyBase class update method does NOT run the superclass update method
function EnemyBase:update(dt)
  self.protected_timer:update(dt)
  self:updateCancelTimers()
  if not self.in_suspense then self.main_timer:update(dt) end
  if self:currentStateIs('grabbed') and self.update_breakout_timer then self.grab_breakout_timer:update(dt) end
  
  if(not self.player) then
    for _,c in ipairs(self.colliders) do
      local collisions = self.collision_world:collisions(c)
      for other, separating_vector in pairs(collisions) do
        if(other.object.name == "Player") then
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
    local test_pos = vector(self.ground_pos.x + (-1 * self.player_is_to), self.ground_pos.y)
    self.moving_into_wall_x = self:checkTileCollision(test_pos) or self:checkEntityCollision(self.hitbox, test_pos)
    
    if (self.moving_into_wall_x) then
      self:updateMovement(dt, vector(0, 0))
      --self:updateMovement(dt, vector(0, self.player.current_movestep.y))
    else
      self:updateMovement(dt, self.player.current_movestep) 
    end
  else 
    if self:currentStateIs('grabbed') then 
      self:updateMovement(dt, self.player.current_movestep) 
    else 
      self:updateMovement(dt, self.Move:getMovementStep(dt))
    end
  end
  
  if self.thrown then 
    self:updateRotationSpeed()

    if self.Move.velocity <= vector(50, 50) and self.Move.velocity >= vector(-50, -50) then 
      self:finishThrow()
    end
    
  end
end

-- @param damage: number: damage done to player, required
-- @param suspense: number: time the player spends in suspense, optional (if not supplied then it's based off damage)
-- @param knockback: number: force applied to player, optional (if not supplied then it's based off damage)
function EnemyBase:addAttackCollider(collider, tag, position_function, damage, suspense, knockback, enabled)
  local attack_collider = self:addCollider(collider, tag, self, position_function, enabled)
  attack_collider.damage = damage
  attack_collider.suspense = suspense
  attack_collider.knockback = knockback
  return attack_collider
end

function EnemyBase:getGrabbed(grab_collider)
  if self.Health:canGetGrabbed() then
    self:changeStates('grabbed')
    self:startBreakOutTimer(grab_collider.object)
    EnemyBase.super.getGrabbed(self, grab_collider)
  else
    grab_collider.signal:emit('grab-failure')
  end
end

function EnemyBase:getThrown(throw_dir)
  self:changeStates('thrown')
  self.grab_breakout_timer:clear()
  EnemyBase.super.getThrown(self, throw_dir)
end

function EnemyBase:finishThrow()
  self:changeStates('alerted')
  EnemyBase.super.finishThrow(self)
end

function EnemyBase:breakOut(direction)
  self:changeStates('hitstun')
  self.grab_breakout_timer:clear()
  self.main_timer:after(0.6, function() self:changeStates('alerted') end)
  EnemyBase.super.breakOut(self, direction)
end

function EnemyBase:startBreakOutTimer(player)
  self.grab_breakout_timer:after(3, function() player.player_components.grab:enemyBreakOut(self, 0, 0.5, 400) end)
end

-- use getmetatable(self) to get the class of an object
function EnemyBase:changeStates(to_state)
  -- calls the exit method on the last state if one is provided
  if self.state.exit then self.state.exit(self) end
  self.state = getmetatable(self).state[to_state]
  if self.state.enter then self.state.enter(self) end
end

function EnemyBase:currentStateIs(is_state)
  return self.state == getmetatable(self).state[is_state] 
end

function EnemyBase:getCurrentState()
  return self.state.name
end

-- collision response function for when an enemy collides with another enemy (only works for collisions between test enemies right now)
function EnemyBase:enemyOnEnemyCollision(separating_vector, other) 
  --if not(self:currentStateIs('hitstun') or other.object:currentStateIs('hitstun')) then 
  self:moveTo(self.ground_pos + vector(separating_vector.x, separating_vector.y)) 
    --other.object:moveTo(other.object.pos - vector(separating_vector.x, separating_vector.y)/2) 
  --end 
end

function EnemyBase:collisionBounce(reverse_seperating_vector, suspense_time)
  self:setSuspense(suspense_time)
  self.Anim:setRotation(0)
  local knockback_dir = vector(-reverse_seperating_vector.x, -reverse_seperating_vector.y):normalizeInplace() 
  self.Move:setMovementSettings(nil, knockback_dir * 11120, nil, nil, nil)
end
  

function EnemyBase:GetRenderPosition()
  error('subclasses should override EnemyBase\'s getRenderPosition() function')
end

return EnemyBase