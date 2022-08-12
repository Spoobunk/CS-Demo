Timer = require "libs.hump.timer"

AttackBase = require "scripts.player.player attacks.player_attack_base"

utilities = require 'scripts.utilities'

AttackMash = AttackBase:extend()

function AttackMash:new(main_class)
  self.main_class = main_class
  self.player = self.main_class.state_manager
  self.anim = self.player.player_components.anim
  self.move = self.player.player_components.move
  self.attack_direction = self.move.face_direction
  self.input_buffer = utilities:createStack()
  self.accepting_input = false
  self.wall_pushed = false

  AttackMash.super.new(self)
  self.stages = {
    {enter = function() self.timer:script(function(wait) self:stage1(wait) end) end,
     knockback = 1000}, 
    {enter = function() self.timer:script(function(wait) self:stage2(wait) end) end,
     knockback = 1000},
    {enter = function() self.timer:script(function(wait) self:stage3(wait) end) end,
     knockback = 1000},
    {enter = function() self.timer:script(function(wait) self:stage4(wait) end) end,
     knockback = 1700},
    {enter = function() self:exit() end}
  }

  self.stages[self.current_stage].enter()
end

function AttackMash:attackInput()
  if self.accepting_input then
    self:nextStage()
  else
    self.input_buffer:push('attack')
  end
end

function AttackMash:swingMash(damage, kb_wait, kb_power)
  self.wall_pushed = false
  --if self.hitbox then self.player:removeCollider(self.hitbox) end
  local collider = self.player.collision_world:rectangle(self.player.position.x + (60 * self.attack_direction), self.player.position.y, 70, 100)
  self.hitbox = self.main_class:addAttackHitbox(collider, "PlayerAttack", function() return self.player.position.x + (60 * self.attack_direction), self.player.position.y end, damage, kb_power, self.signal, kb_wait)
  self.signal:register('pushed-against-wall', function(distance) self:pushBack(distance) end)
  
  self.move:defaultMovementSettings() 
  self.move:Set_Movement_Settings(vector(0, 0), vector(self.attack_direction * 1400, self.move.velocity.y), 50, 0.7, 700)
  --self.timer:after(0.0, function() self.player:setInputBuffering('spin', true) self.player:setInputBuffering('grab', true) end)
  -- no need to call the exit method manually, it's called whenever the player's state transitions from the attacking state
  self.timer:after(0.4, function() --[[self:exit()]] self.player:change_states('idle') end)
  self.timer:after(0.06, function() self.player:removeCollider(self.hitbox) end)
end

function AttackMash:pushBack(distance)
  if not self.wall_pushed then
    --self.player:moveTo(vector(self.player.pos.x - self.player.current_movestep.x, self.player.pos.y))
    --self.move:Set_Movement_Settings(vector(0, 0), vector(-self.attack_direction * distance * 2, 0), 50, 0.7, nil)
    -- the approximate time it will take the player to reach a third of the way to the enemy pinned against a wall
    local half_time = self.move.velocity.x == 0 and 0 or math.abs((distance / 2) / self.move.velocity.x)
    --print(half_time)
    --self.timer:after(half_time, function() self.move:Set_Movement_Settings(vector(0, 0), vector(-self.attack_direction * (self.stages[self.current_stage].knockback / 2), 0), 50, 0.7, nil) end)
    --local push_back_vel = self.move.velocity.x == 0 and 500 or math.abs(self.move.velocity.x) 
   -- self.timer:after(half_time, function() self.move:Set_Movement_Settings(vector(0, 0), vector(-self.attack_direction * (push_back_vel), 0), 50, 0.7, nil) end)
    self.timer:after(half_time, function() self.move:Set_Movement_Settings(vector(0, 0), vector(-self.attack_direction * (self.move.velocity.x == 0 and 500 or math.abs(self.move.velocity.x)), 0), 50, 0.7, nil) end)
    --print(self.move.velocity.x)
    self.wall_pushed = true
  end
end

function AttackMash:nextStage()
  self.timer:clear()
  -- removes the attack hitbox if it still exists so that hitboxes don't pile up on eachother
  if self.hitbox then self.player:removeCollider(self.hitbox) end
  self.accepting_input = false
  -- resetting the input buffer every time stage changes  
  self.input_buffer = utilities:createStack()
  self.player:clearInputBuffer()
  
  AttackMash.super.nextStage(self)
end

function AttackMash:stage1(wait)
  self.anim:Switch_Animation('mash1') 
  self:swingMash(3, 0.45, self.stages[self.current_stage].knockback)

  wait(0.11)
  self.accepting_input = true
  if self.input_buffer:pop() then self:nextStage() end
  wait(0.2)
  self.player:setInputBuffering('spin', true)
  self.player:setInputBuffering('grab', true)
end

function AttackMash:stage2(wait)
  -- ready time
  self.anim:Switch_Animation('mashready2')
  wait(0.08)
  self.anim:Switch_Animation('mash2')
  self:swingMash(3, 0.45, self.stages[self.current_stage].knockback)
  wait(0.11)
  self.accepting_input = true 
  if self.input_buffer:pop() then self:nextStage() end
  wait(0.2)
  self.player:setInputBuffering('spin', true)
  self.player:setInputBuffering('grab', true)
end

function AttackMash:stage3(wait)
  -- ready time
  self.anim:Switch_Animation('mashready3')
  wait(0.08)
  self.anim:Switch_Animation('mash3')
  self:swingMash(3, 0.45, self.stages[self.current_stage].knockback)
  wait(0.11)
  self.accepting_input = true 
  if self.input_buffer:pop() then self:nextStage() end
  wait(0.2)
  self.player:setInputBuffering('spin', true)
  self.player:setInputBuffering('grab', true)
end

function AttackMash:stage4(wait)
  -- ready time
  self.anim:Switch_Animation('mashready2')
  wait(0.08)
  self.anim:Switch_Animation('mash2')
  self:swingMash(6, 0.02, self.stages[self.current_stage].knockback)
  wait(0.28)
  self.player:setInputBuffering('spin', true)
  self.player:setInputBuffering('grab', true)
  self.player:setInputBuffering('attack', true)
end

-- here we reset any values we were messin' with
function AttackMash:exit()
  self.move:defaultMovementSettings() 
  -- get rid of all attack hitboxes
  local attack_hitboxes = {}
  for _, c in ipairs(self.player.colliders) do
    if c.tag == "PlayerAttack" then table.insert(attack_hitboxes, c) end
  end
  for i, c in ipairs(attack_hitboxes) do
    self.player:removeCollider(c)
  end
end
  
return AttackMash