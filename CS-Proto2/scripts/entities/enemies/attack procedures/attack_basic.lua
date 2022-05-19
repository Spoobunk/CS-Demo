Object = require "libs.classic.classic"
Timer = require "libs.hump.timer"

AttackBasic = Object:extend()

function AttackBasic:new(main_class)
  self.main_class = main_class
  self.target = vector(0, 0)
  self.current_stage = 1
  self.stages = {
    {enter = function() self:stage1() end, 
     exit_condition = function() return self.main_class.pos.y < self.target.y + 0.5 and self.main_class.pos.y > self.target.y - 0.5 end},
    {enter = function() self:stage2() end}
      --exit_condition = function() return  "poop" end}
  }
  self.stages[self.current_stage].enter()
  self.timer = Timer.new()
end

function AttackBasic:nextStage()
  self.current_stage = self.current_stage + 1
  self.stages[self.current_stage].enter()
end

-- getting in line with the player
function AttackBasic:stage1()
  self.main_class.following_player = false
  self.target = vector(self.main_class.player.position.x + 10, self.main_class.player.position.y)
  local toward_target = self.target - self.main_class.pos
  toward_target = toward_target:normalizeInplace()
  self.main_class.Move:setMovementSettings(toward_target)
end

-- wind up 
function AttackBasic:stage2()
  self.main_class.Move:setMovementSettings(vector(0, 0), vector(0, 0), 0, 0)
  self.main_class.Anim:switchAnimation('attack_windup')
  self.timer:after(0.2, function() 
    self.main_class.Anim:switchAnimation('attack') 
    self.main_class.Move:defaultMovementSettings() 
    self.main_class.Move:setMovementSettings(vector(1, 0)) 
  end)
end

function AttackBasic:update(dt)
  if self.stages[self.current_stage].exit_condition then
    if self.stages[self.current_stage].exit_condition() then self:nextStage() end
  end

  self.timer:update(dt)
end

return AttackBasic