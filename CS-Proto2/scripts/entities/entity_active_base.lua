Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"

Entity = require "scripts.entities.entity_base"
MoveComponent = require "scripts.entities.entity_move_base"

utilities = require 'scripts.utilities'

Active = Entity:extend()

function Active:new(x, y, collision_world, tile_world, main_hitbox)
  Active.super.new(self, x, y, collision_world, tile_world)
  self.Move = MoveComponent(0, 0, 0)
  self.protected_timer = Timer.new()
  -- saves the cancel timer object of the suspense timer that's currently running. nil if the entity is not in suspense
  self.current_suspense_timer = nil
  self.in_suspense = false
  -- saves the tween function currently affecting the height of the entity (there should only ever be one active at once) (?)
  self.current_height_tween = nil
  self.cancel_timers = {}
end

function Active:update()
  self.protected_timer:update(dt)
  self:updateCancelTimers()
end

-- @param time: number, time the entity spends in suspense; required
-- @param canMove: boolean, whether the entity has their movement updated while in suspense; defaults to false
-- @param afterFunc: function, function to run after suspense has ended; optional
function Active:setSuspense(time, canMove, afterFunc)
  --print(self)
  -- if a suspense timer is already running, then that one is cancelled before the new one is set up.
  if self.current_suspense_timer then self.protected_timer:cancel(self.current_suspense_timer.handle) self.current_suspense_timer.action() end
  
  self.in_suspense = true
  if not canMove then self.Move.update_movement = false end
  local suspense_end = function() 
    self.in_suspense = false 
    if not canMove then self.Move.update_movement = true end
    if afterFunc then afterFunc() end
    self.current_suspense_timer = nil
  end
  
  self.current_suspense_timer = self:addCancelTimer(time, function() return self.in_suspense == true end, suspense_end)
end

-- @param duration: number, amount of time that the first jump takes
-- @param target: number, target height for the first jump
-- @param method: string, name of tween method being used (no in/out prefixes)
-- @param after: function, function run after the entire jump series is finished
-- @param duration_mod: function, a function that takes two arguments: the number of jumps that have transpired in the series, and the duration of the last jump. it returns the duration that the new jump will use. 
-- @param target_mod: function, same as above, but for target height
-- @param jump_total: number, the total number of jumps in the series
-- @param jump_num: number, the number of the current jump taking place in the series (starts at 0)
-- no support for changing the fall_duration_mod of the jumps at the moment :/
function Active:jumpSeries(duration, target, method, after, duration_mod, target_mod, jump_total, jump_num)
  jump_num = jump_num or 0
  if jump_num >= jump_total then if after then after() end return false end
  duration = duration_mod(jump_num, duration)
  target = target_mod(jump_num, target)
  if target < 0 then target = 0 end
  if jump_num == 3 then self.in_suspense = true end
  jump_num = jump_num + 1
  self:jump(duration, target, method, function() self:jumpSeries(duration, target, method, after, duration_mod, target_mod, jump_total, jump_num) end)
end
  
--@param rise_duration: number, duration of the rise part of the jump (fall duration is this number divided by 2 by default)
--@param target: number, the height the entity will reach with its jump
--@param method: string, name of tween method being used (WITHOUT in/out prefixes)
--@param fall_duration_mod: number, the number by which the fall duration is divided
function Active:jump(rise_duration, target, method, after, fall_duration_mod)
  --up
  self:setHeightTween(rise_duration, target, 'out-' .. method, function()
      --down (usually faster than the up)
      local fdm = fall_duration_mod or 2
      self:setHeightTween(rise_duration / fdm, 0, 'in-' .. method, after)
  end)
end

function Active:setHeightTween(duration, target, method, after)

  self:cancelHeightTween()
  local finished_function = function() self.current_height_tween = nil if after then after() end end
  self.current_height_tween = self.Move.height_timer:tween(duration, self, {height = target}, method, finished_function)
end

function Active:cancelHeightTween()
  if self.current_height_tween then self.Move.height_timer:cancel(self.current_height_tween) self.current_height_tween = nil end
end

function Active:addCancelTimer(time, condition, action)
  local ct = {}
  ct.action = function() action() self:removeCancelTimer(ct.handle) end
  ct.condition = condition
  ct.handle = self.protected_timer:after(time, ct.action)
  table.insert(self.cancel_timers, ct)
  return ct
end

function Active:removeCancelTimer(handle)
  for i, ct in ipairs(self.cancel_timers) do
    if ct.handle == handle then table.remove(self.cancel_timers, i) end
  end
end

function Active:updateCancelTimers()
  for i = #self.cancel_timers, 1, -1 do 
    local ct = self.cancel_timers[i]
    if not ct.condition() then self.protected_timer:cancel(ct.handle) ct.action() end
  end
end

return Active