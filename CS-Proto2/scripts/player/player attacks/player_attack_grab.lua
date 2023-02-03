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
  
  self.player.camera:setTarget(self.player.camera:ellipsify(vector(self.attack_direction * self.player.camera.MAX_TARGET_DISTANCE, 0)))

  AttackGrab.super.new(self)
  self.signal:register('grab-success', function(grabbable) self:onGrab(grabbable) end)
  self.stages = {
    {enter = function() self.timer:script(function(wait) self:stage1(wait) end) end}, 
    {enter = function() self:exit() end}
  }

  self.stages[self.current_stage].enter()
end

function AttackGrab:onGrab(grabbable)
  self.player:setSuspense(0.1, true)
  grabbable:setSuspense(0.1, true)
  self.grab:onGrab(grabbable)
  self.grab:startHold()
  -- originally I waited a bit before transitioning to the holding state on the player, but I don't remember why I set it up that way.
  --self.timer:after(0.2, function() self.grab:startHold() end)
  self.player.hand:onGrab(self.attack_direction)
    -- get rid of all grab hitboxes
  for i = #self.player.colliders, 1, -1 do 
    local c = self.player.colliders[i]
    if c.tag == "PlayerGrab" then self.player:removeCollider(c) end
  end
end

function AttackGrab:stage1(wait)
  -- wind up
  --self.anim:Switch_Animation('mashready3')
  self.move:Set_Movement_Settings(vector(0, 0), nil, 50, 0.7, 700)
  self.player.hand:grabSwing(self.attack_direction)
  self.move:Set_Movement_Settings(vector(0, 0), vector(self.attack_direction * 1400, self.main_class.move_input.y * 350), 50, 0.7, 700)
  wait(0.08)
  -- swing
  --self.anim:Switch_Animation('mash3')
  

  local collider = self.player.collision_world:rectangle(self.player.pos.x + (60 * self.attack_direction), self.player.pos.y, 70, 100)
  local hitbox = self.main_class:addGrabHitbox(collider, function() return self.player.pos.x + (60 * self.attack_direction), self.player.pos.y end, self.signal)
  wait(0.06)
  self.player:removeCollider(hitbox)
  wait(0.22)
  self.player:setInputBuffering('all', true)
  wait(0.17)
  self.player:change_states('idle')
end

function AttackGrab:exit(to_state)
  -- makes it so when the player transitions from grabbing to holding, they don't immediately lose all momentum.
  if to_state.name ~= 'holding' then self.move:defaultMovementSettings() end
  
  -- get rid of all grab hitboxes
  for i = #self.player.colliders, 1, -1 do 
    local c = self.player.colliders[i]
    if c.tag == "PlayerGrab" then self.player:removeCollider(c) end
  end
  if to_state.name == 'idle' then self.player.hand:retractArm(0.2) end
end

return AttackGrab