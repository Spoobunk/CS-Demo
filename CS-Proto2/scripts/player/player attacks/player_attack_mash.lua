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
  self.pushed_back = false
  
  self.player.camera:setTarget(self.player.camera:ellipsify(vector(self.attack_direction * self.player.camera.MAX_TARGET_DISTANCE, 0)))

  AttackMash.super.new(self)
  self.signal:register('hit-confirm', function() self:onHit() end)
  self.signal:register('pushed-against-wall', function(distance) self:pushBack(distance) end)
  self.stages = {
    {enter = function() self.timer:script(function(wait) self:stage1(wait) end) end,
     suspense_time = 0.02}, 
    {enter = function() self.timer:script(function(wait) self:stage2(wait) end) end,
     suspense_time = 0.02},
    {enter = function() self.timer:script(function(wait) self:stage3(wait) end) end,
     suspense_time = 0.02},
    {enter = function() self.timer:script(function(wait) self:stage4(wait) end) end,
     suspense_time = 0.08},
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

function AttackMash:pushBack(distance)
  if not self.pushed_back then
    distance = math.abs(distance)
    -- the approximate time it will take the player to reach a third of the way to the enemy pinned against a wall
    local half_time = self.move.velocity.x == 0 and 0 or math.abs((distance / 2) / self.move.velocity.x)
    --print(distance)
    -- alternate way of pushing back that's feels quicker, but is less predictable
    --self.timer:after(half_time, function() self.move:Set_Movement_Settings(vector(0, 0), vector(-self.attack_direction * (self.stages[self.current_stage].knockback / 2), 0), 50, 0.7, nil) end)
    self.player.protected_timer:after(half_time, function() self.move:Set_Movement_Settings(vector(0, 0), vector(-self.attack_direction * (self.move.velocity.x == 0 and 500 or math.abs(self.move.velocity.x * 1.5)), 0), 50, 0.7, nil) end)
    --print(self.move.velocity.x)
    --local dis_range = (distance/2) < 60 and math.min((60 - (distance/2)) / 60, 1) * 700 or 0
    --self.player.protected_timer:after(half_time, function() self.move:Set_Movement_Settings(vector(0, 0), vector(-self.attack_direction * dis_range, 0), 50, 0.7, nil) end)
    self.pushed_back = true
  end
end

function AttackMash:onHit() 
  if not self.player.in_suspense then 
    self.player:setSuspense(self.stages[self.current_stage].suspense_time, true, function() self.signal:emit('suspense-end') end) 
  end 
end

function AttackMash:swingMash(damage, kb_wait, kb_power)
  self.pushed_back = false
  --local collider = self.player.collision_world:rectangle(self.player.pos.x + (60 * self.attack_direction), self.player.pos.y, 70, 100)
  local left_side = self.player.pos.x + (30 * self.attack_direction)
  local collider = self.player.collision_world:polygon(
    0, -50, 
    20, -45, 
    40, -30, 
    50, -10, 
    50, 10, 
    40, 30, 
    20, 45, 
    0, 50)
  if self.attack_direction < 0 then collider:rotate(math.pi) end
  self.hitbox = self.main_class:addAttackHitbox(collider, function() return self.player.pos.x + (50 * self.attack_direction), self.player.pos.y end, damage, kb_power, self.signal, kb_wait, self.stages[self.current_stage].suspense_time)
  
  self.move:defaultMovementSettings() 
  local y_vel = self.main_class.move_input.y * 350
  self.move:Set_Movement_Settings(vector(0, 0), vector(self.attack_direction * 1400, y_vel), 50, 0.7, 700)
  -- no need to call the exit method manually, it's called whenever the player's state transitions from the attacking state
  self.timer:after(0.4, function() self.player:change_states('idle') end)
  -- make it so the timer to remove the collider isn't affected by being in-suspense
  self.player.protected_timer:after(0.07, function() self.player:removeCollider(self.hitbox) end)
end

function AttackMash:nextStage()
  self.timer:clear()
  -- removes the attack hitbox if it still exists so that hitboxes don't pile up on eachother
  --if self.hitbox then self.player:removeCollider(self.hitbox) end
  self.accepting_input = false
  -- resetting the input buffer every time stage changes  
  self.input_buffer = utilities:createStack()
  self.player:clearInputBuffer()
  
  AttackMash.super.nextStage(self)
end

function AttackMash:stage1(wait)
    -- wind-up 
  self.anim:Switch_Animation('mashready3')
  self.player.hand:readySwing(1, self.attack_direction)
  wait(0.08)
  -- swing
  --self.anim:Switch_Animation('mash1') 
  self.player.hand:swing(1, self.attack_direction)
  self:swingMash(3, 0.45, 1000)
  wait(0.08)
  -- can proceed to next stage
  self.accepting_input = true
  if self.input_buffer:pop() then self:nextStage() end
  wait(0.2)
  -- can buffer other inputs
  self.player:setInputBuffering('spin', true)
  self.player:setInputBuffering('grab', true)
end

function AttackMash:stage2(wait)
  -- wind-up 
  self.anim:Switch_Animation('mashready2')
  self.player.hand:readySwing(2, self.attack_direction)
  wait(0.08)
  -- swing
  --self.anim:Switch_Animation('mash2')
  self.player.hand:swing(2, self.attack_direction)
  self:swingMash(3, 0.45, 1000)
  wait(0.08)
  -- can proceed to next stage
  self.accepting_input = true 
  if self.input_buffer:pop() then self:nextStage() end
  wait(0.2)
  -- can buffer other inputs
  self.player:setInputBuffering('spin', true)
  self.player:setInputBuffering('grab', true)
end

function AttackMash:stage3(wait)
  -- wind-up 
  self.anim:Switch_Animation('mashready3')
  self.player.hand:readySwing(3, self.attack_direction)
  wait(0.08)
  -- swing
  --self.anim:Switch_Animation('mash3')
  self.player.hand:swing(3, self.attack_direction)
  self:swingMash(3, 0.45, 1000)
  wait(0.08)
  -- can proceed to next stage
  self.accepting_input = true 
  if self.input_buffer:pop() then self:nextStage() end
  wait(0.2)
  -- can buffer other inputs
  self.player:setInputBuffering('spin', true)
  self.player:setInputBuffering('grab', true)
end

function AttackMash:stage4(wait)
  -- wind-up 
  self.anim:Switch_Animation('mashready2')
  self.player.hand:readySwing(4, self.attack_direction)
  wait(0.12)
  -- swing
  --self.anim:Switch_Animation('mash2')
  self.player.hand:swing(4, self.attack_direction)
  self:swingMash(6, 0.02, 1700)
  wait(0.28)
  -- can buffer all inputs
  self.player:setInputBuffering('all', true)
end

-- here we reset any values we were messin' with
function AttackMash:exit()
  self.move:defaultMovementSettings() 
  -- get rid of all attack hitboxes
  for i = #self.player.colliders, 1, -1 do 
    local c = self.player.colliders[i]
    if c.tag == "PlayerAttack" then self.player:removeCollider(c) end
  end
  self.player.hand:retractArm(0.2)
end
  
return AttackMash