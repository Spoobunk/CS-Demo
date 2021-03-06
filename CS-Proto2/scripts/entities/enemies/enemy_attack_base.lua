Object = require "libs.classic.classic"
Timer = require "libs.hump.timer"

AttackBase = Object:extend()

function AttackBase:new()
  self.stages = {}
  self.current_stage = 1
  self.timer = Timer.new()
  self.stages[self.current_stage].enter()
end

function AttackBase:nextStage()
  self.current_stage = self.current_stage + 1
  self.stages[self.current_stage].enter()
end

function AttackBase:update(dt)
  if self.stages[self.current_stage].exit_condition then
    if self.stages[self.current_stage].exit_condition() then self:nextStage() end
  end

  if self.stages[self.current_stage].update then
    self.stages[self.current_stage].update()
  end
  self.timer:update(dt)
end

return AttackBase