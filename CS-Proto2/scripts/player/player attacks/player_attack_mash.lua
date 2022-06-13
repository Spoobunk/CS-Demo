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
  
    self.current_stage = 1
  self.stages = {
    {enter = function() self:stage1() end}, 
    {enter = function() self:stage2() end},
    {enter = function() self:stage3() end},
    {enter = function() self:stage4() end},
    {enter = function() self:exit() end}
  }

  self.timer = Timer.new()
  self.stages[self.current_stage].enter()
end

function AttackMash:attackInput()
  if self.accepting_input then
    self:nextStage()
  else
    self.input_buffer:push('attack')
  end
end

function AttackMash:swingMash()
  --if self.hitbox then self.player:removeCollider(self.hitbox) end
  local hitbox = self.player.collision_world:rectangle(self.player.position.x + (60 * self.attack_direction), self.player.position.y, 70, 100)
  self.hitbox = self.player:addCollider(hitbox, "PlayerAttack", self.player, function() return self.player.position.x + (60 * self.attack_direction), self.player.position.y end) 
  self.move:defaultMovementSettings() 
  self.move:Set_Movement_Settings(vector(0, 0), vector(self.attack_direction * 1400, self.move.velocity.y), 50, 0.7, 700)
  self.timer:after(0.4, function() self:exit() end)
  self.timer:after(0.1, function() self.player:removeCollider(self.hitbox) end)
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
  self:swingMash()
  self.timer:after(0.14, function() self.accepting_input = true if self.input_buffer:pop() then self:nextStage() end end)
end

function AttackMash:stage2()
  self.anim:Switch_Animation('mashready2')
  self.timer:after(0.12, function() 
    self.anim:Switch_Animation('mash2')
    self:swingMash()
    self.timer:after(0.14, function() self.accepting_input = true if self.input_buffer:pop() then self:nextStage() end end)
  end)
end

function AttackMash:stage3()
  self.anim:Switch_Animation('mashready3')
  self.timer:after(0.12, function()
    self.anim:Switch_Animation('mash3') 
    self:swingMash()
    self.timer:after(0.14, function() self.accepting_input = true if self.input_buffer:pop() then self:nextStage() end end)
  end)
end

function AttackMash:stage4()
  self.anim:Switch_Animation('mashready2')
  self.timer:after(0.12, function() 
    self.anim:Switch_Animation('mash2')
    self:swingMash()
  end)
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
  
  self.main_class:exit()
end
  
return AttackMash