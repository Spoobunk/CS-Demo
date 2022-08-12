Timer = require "libs.hump.timer"

AttackBase = require "scripts.player.player attacks.player_attack_base"

utilities = require 'scripts.utilities'

AttackGrab = AttackBase:extend()

function AttackGrab:new(main_class)
  self.main_class = main_class
  self.player = self.main_class.state_manager
  self.anim = self.player.player_components.anim
  self.move = self.player.player_components.move
  self.grab = self.player.player_components.grab
  self.attack_direction = self.move.face_direction

  AttackGrab.super.new(self)
  self.signal:register('grab-success', function(grabbable) self.grab:onGrab(grabbable) end)
  self.stages = {
    {enter = function() self.timer:script(function(wait) self:stage1(wait) end) end}, 
    {enter = function() self.timer:script(function(wait) self:stage2(wait) end) end},
    {enter = function() self.timer:script(function(wait) self:stage3(wait) end) end},
    {enter = function() self.timer:script(function(wait) self:stage4(wait) end) end},
    {enter = function() self:exit() end}
  }

  self.stages[self.current_stage].enter()
end

function AttackGrab:stage1(wait)
  self.anim:Switch_Animation('mashready3')
  self.move:Set_Movement_Settings(vector(0, 0), nil, 50, 0.7, 700)
  wait(0.15)
  self.anim:Switch_Animation('mash3')
  self.move:Set_Movement_Settings(vector(0, 0), vector(self.attack_direction * 1400, self.move.velocity.y), 50, 0.7, 700)
  local collider = self.player.collision_world:rectangle(self.player.position.x + (60 * self.attack_direction), self.player.position.y, 70, 100)
  local hitbox = self.main_class:addGrabHitbox(collider, function() return self.player.position.x + (60 * self.attack_direction), self.player.position.y end, self.signal)
  wait(0.06)
  self.player:removeCollider(hitbox)
  wait(0.22)
  self.player:setInputBuffering('spin', true)
  self.player:setInputBuffering('grab', true)
  self.player:setInputBuffering('attack', true)
  wait(0.17)
  self.player:change_states('idle')
end

function AttackGrab:exit(to_state)
  -- makes it so when the player transitions from grabbing to holding, they don't immediately lose all momentum.
  if to_state.name ~= 'holding' then self.move:defaultMovementSettings() end
  -- pretty sure this is a waste, all i need to do is iterate through the collider array backwards and removing elements won't be a problem.
  -- get rid of all grab hitboxes
  local grab_hitboxes = {}
  for _, c in ipairs(self.player.colliders) do
    if c.tag == "PlayerGrab" then table.insert(grab_hitboxes, c) end
  end
  for i, c in ipairs(grab_hitboxes) do
    self.player:removeCollider(c)
  end
end

return AttackGrab