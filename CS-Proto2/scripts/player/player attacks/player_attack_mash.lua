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
    {enter = function() self:stage1() end,
     knockback = 1000}, 
    {enter = function() self:stage2() end,
     knockback = 1000},
    {enter = function() self:stage3() end,
     knockback = 1000},
    {enter = function() self:stage4() end,
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
  --self.hitbox = self.player:addCollider(collider, "PlayerAttack", self.player, function() return self.player.position.x + (60 * self.attack_direction), self.player.position.y end) 
  self.hitbox = self.main_class:addAttackHitbox(collider, "PlayerAttack", function() return self.player.position.x + (60 * self.attack_direction), self.player.position.y end, damage, kb_power, self.signal, kb_wait)
  self.signal:register('pushed-against-wall', function(distance) self:pushBack(distance) end)
  
  self.move:defaultMovementSettings() 
  self.move:Set_Movement_Settings(vector(0, 0), vector(self.attack_direction * 1400, self.move.velocity.y), 50, 0.7, 700)
  self.timer:after(0.4, function() self:exit() end)
  self.timer:after(0.05, function() self.player:removeCollider(self.hitbox) end)
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
  self.accepting_input = false
  -- resetting the input buffer every time stage changes  
  self.input_buffer = utilities:createStack()
  AttackMash.super.nextStage(self)
end

function AttackMash:stage1()
  self.anim:Switch_Animation('mash1') 
  self:swingMash(3, 0.5, self.stages[self.current_stage].knockback)
  self.timer:after(0.11, function() self.accepting_input = true if self.input_buffer:pop() then self:nextStage() end end)
end

function AttackMash:stage2()
  self.anim:Switch_Animation('mashready2')
  -- time between ready animation and actual swing
  self.timer:after(0.1, function() 
    self.anim:Switch_Animation('mash2')
    self:swingMash(3, 0.5, self.stages[self.current_stage].knockback)
    self.timer:after(0.11, function() self.accepting_input = true if self.input_buffer:pop() then self:nextStage() end end)
  end)
end

function AttackMash:stage3()
  self.anim:Switch_Animation('mashready3')
  -- time between ready animation and actual swing
  self.timer:after(0.1, function()
    self.anim:Switch_Animation('mash3') 
    self:swingMash(3, 0.5, self.stages[self.current_stage].knockback)
    self.timer:after(0.11, function() self.accepting_input = true if self.input_buffer:pop() then self:nextStage() end end)
  end)
end

function AttackMash:stage4()
  self.anim:Switch_Animation('mashready2')
  -- time between ready animation and actual swing
  self.timer:after(0.1, function() 
    self.anim:Switch_Animation('mash2')
    self:swingMash(6, 0.02, self.stages[self.current_stage].knockback)
  end)
end

-- here we reset any values we were messin' with
function AttackMash:exit()
  self.move:defaultMovementSettings() 
  self.signal:emit('attack-end')
  -- get rid of all attack hitboxes
  local attack_hitboxes = {}
  for _, c in ipairs(self.player.colliders) do
    if c.tag == "PlayerAttack" then table.insert(attack_hitboxes, c) end
  end
  for i, c in ipairs(attack_hitboxes) do
    self.player:removeCollider(c)
  end
  
  self.main_class:exit()
end
  
return AttackMash