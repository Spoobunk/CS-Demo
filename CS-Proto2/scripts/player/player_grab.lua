vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"
Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

PlayerGrab = Object:extend()

function PlayerGrab:new(state_manager)
  self.state_manager = state_manager
  self.holding = nil
  self.aim_diagonal = nil
  self.can_aim = true
  self.throw_dir = vector(0, 1)
  self.hold_timer = nil
  self.grab_timer = Timer.new()
end

-- called the frame the enemy collides with a grab hitbox
function PlayerGrab:onGrab(grabbed)
  self.holding = grabbed
end

-- called when the player's state should change to 'holding'
function PlayerGrab:startHold()
  if not self.holding then return false end
  self.state_manager:change_states('holding')
  self.grab_timer:after(0.08, function() self.state_manager.player_components.move:Set_Movement_Settings(nil, nil, 25, 0.5, 100) end)
  self.holding:moveTo(vector(self.state_manager.position.x + (60 * self.state_manager.player_components.move.face_direction), self.state_manager.position.y + 25))
  self.holding.height = 50
  if self.state_manager.is_holding_input.grab then 
    self.hold_timer = self.grab_timer:during(1.3, function() 
        if not self.state_manager.is_holding_input.grab then self.grab_timer:cancel(self.hold_timer) end
      end, function() 
        if self.state_manager.is_holding_input.grab then self:readyThrow() end
      end)
  end
end

function PlayerGrab:update(dt)
  self.grab_timer:update(dt)

  if self.holding then
    self.holding.update_breakout_timer = self.state_manager:Current_State_Is('holding') or self.state_manager:Current_State_Is('throwing')
    --self.holding:updateMovement(dt, self.state_manager.current_movestep)
    if self.state_manager:Current_State_Is('holding') then 
      self.holding:moveTo(vector(self.state_manager.position.x + (60 * self.state_manager.player_components.move.face_direction), self.state_manager.position.y + 25)) 
      self.throw_dir = vector(self.state_manager.player_components.move.face_direction, 0)
      
    elseif self.state_manager:Current_State_Is('throwing') then
      local raw_input = self.state_manager.player_components.move.raw_input
      
      if self.can_aim and (raw_input.x ~= 0 or raw_input.y ~= 0) then
        -- weird shit I wrote so that when you do a diagonal direction, it ignores inputs and sticks there for a bit. This is so that when you want to point in a diagonal direction, it doesn't switch back to a cardinal direction once you stop holding the buttons, if you release then fast enough.
        if self.aim_diagonal and (self.aim_diagonal.x ~= raw_input.x or self.aim_diagonal.y ~= raw_input.y) then self.can_aim = false self.grab_timer:after(0.01, function() self.aim_diagonal = nil self.can_aim = true end) else      
          
          local hold_pos = raw_input:rotated(math.pi)
          self.holding:moveTo(vector(self.state_manager.position.x + (60 * hold_pos.x), self.state_manager.position.y + (60 * hold_pos.y)))
          self.throw_dir = raw_input
          if raw_input.x ~= 0 and raw_input.y ~= 0 then self.aim_diagonal = vector(raw_input.x, raw_input.y) end

        end
      end
      self.state_manager.camera:setTarget(self.throw_dir:normalized() * self.state_manager.camera.MAX_TARGET_DISTANCE)
    end
  end

end

function PlayerGrab:readyThrow()
  self.state_manager:change_states('throwing')
  self.state_manager.player_components.move:Set_Movement_Settings(vector(0, 0), nil, nil, nil, nil)
  local hold_pos = self.throw_dir:rotated(math.pi)
  self.holding:moveTo(vector(self.state_manager.position.x + (60 * hold_pos.x), self.state_manager.position.y + (60 * hold_pos.y)))
end

function PlayerGrab:doThrow()
  self.holding:moveTo(vector(self.state_manager.position.x + (20 * self.throw_dir.x), self.state_manager.position.y + (20 * self.throw_dir.y)))
  self.holding:getThrown(self.throw_dir)
  self.holding = nil
  self.state_manager:change_states('dormant')
  self.state_manager.player_components.move:Set_Movement_Settings(nil, self.throw_dir:normalizeInplace():rotated(math.pi) * 200, nil, 0.5, 500)
  self.grab_timer:after(0.5, function() self.state_manager:change_states('idle') self.state_manager:setInputBuffering('all', false) self.state_manager.player_components.move:defaultMovementSettings() end)
  self.grab_timer:after(0.32, function() self.state_manager:setInputBuffering('all', true) end)
end

function PlayerGrab:enemyBreakOut(enemy, damage, suspense, kb_pow)
  if self.holding and self.holding == enemy then 
    if self.state_manager:Current_State_Is('holding') then 
      self.state_manager.player_components.health:takeDirectDamage(damage, suspense, kb_pow, self.throw_dir:rotated(math.pi)) 
    elseif self.state_manager:Current_State_Is('throwing') then
      self.state_manager.player_components.health:takeDirectDamage(damage, suspense, kb_pow, self.throw_dir) 
    end
  end
end

function PlayerGrab:abortGrab(suspense_time, last_state)
  if self.holding then 
    self.holding:setSuspense(suspense_time)
    self:releaseHold(last_state)
  end
end
  
function PlayerGrab:releaseHold(last_state)
  -- if the player was in a state other than holding or throwing before getting hit, the default breakout direction will be perpendicular to the player's hitstun
  local direction = self.state_manager.player_components.move.velocity:perpendicular()
  if last_state == 'holding' then 
    direction = self.throw_dir
  elseif last_state == 'throwing' then
    direction = self.throw_dir:rotated(math.pi)
  end
  self.holding:breakOut(direction)
  self.holding = nil
end

return PlayerGrab