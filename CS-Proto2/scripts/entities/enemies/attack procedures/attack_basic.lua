Object = require "libs.classic.classic"
Timer = require "libs.hump.timer"

AttackBasic = Object:extend()

function AttackBasic:new(main_class)
  self.main_class = main_class
  self.target = vector(0, 0)
  self.attack_direction = nil
  self.current_stage = 1
  self.hop_height = {y = 0}
  self.stages = {
    {enter = function() self:stage1() end, 
     --exit_condition = function() local distance = (self.main_class.pos.y - self.target.y) * self.target_mod return self.main_class.pos.y < self.target.y + 1 and self.main_class.pos.y > self.target.y - 1 end},
     exit_condition = function() local distance = (self.main_class.pos.y - self.target.y) * self.target_mod return distance > 0.1 end},
    {enter = function() self:stage2() end},
      --exit_condition = function() return  "poop" end}
    {enter = function() self:stage3() end,
     update = function() self.main_class.pos.y = self.ground_level - self.hop_height.y end},
   
    {enter = function() self:stage4() end},
    
    {enter = function() self:exit() end}
  }

  self.timer = Timer.new()
  self.stages[self.current_stage].enter()
end

function AttackBasic:nextStage()
  self.current_stage = self.current_stage + 1
  self.stages[self.current_stage].enter()
end

-- getting in line with the player
function AttackBasic:stage1()
  self.attack_direction = self.main_class.player_is_to
    
  self.main_class.following_player = false
  self.main_class.facing_player = false
  self.target = vector(self.main_class.player.position.x + (100 * -self.attack_direction), self.main_class.player.position.y)
  -- target_mod: tells whether the enemy is above or below target position
  local target_distance = (self.target.y - self.main_class.pos.y)
  self.target_mod = target_distance == 0 and 0 or target_distance / math.abs(target_distance)
  
  --print(self.target_mod)
  
  local toward_target = self.target - self.main_class.pos
  toward_target = toward_target:normalizeInplace()
  self.main_class.Move:setMovementSettings(toward_target, vector(0, 0), 4, 0.09, 150) 
  --This stage should end when the enemy is lined up with the player as defined in the exit condition, but in the case that doesn't happen, this timer will end it the attack.
  -- will implment
end

-- wind up 
function AttackBasic:stage2()
  self.main_class.Move:setMovementSettings(vector(0, 0), vector(0, 0), 0, 0)
  self.main_class.Anim:switchAnimation('attack_windup')
  self.timer:after(0.5, function() self:nextStage() end)
end

-- thrust forward
function AttackBasic:stage3()
  self.main_class.Anim:switchAnimation('attack') 
  self.main_class.Move:defaultMovementSettings() 
  self.main_class.Move:setMovementSettings(vector(self.attack_direction, 0), nil, 50, 0.3, 80)
  -- saves where the player's y is currently so the player's height doesn't keep getting added to itself.
  self.ground_level = self.main_class.pos.y
  local number_of_hops = 0
  local up, down
  up = function() self.timer:tween(0.15, self.hop_height, {y = 10}, 'out-quart', function() number_of_hops = number_of_hops + 1 down() end) end
  down = function() self.timer:tween(0.15, self.hop_height, {y = 0}, 'in-quart', function() if number_of_hops >= 3 then self:nextStage() else up() end end) end
  up()
end

function AttackBasic:stage4()
  self.main_class.Move:setMovementSettings(nil, nil, 0, 0.3, nil)
  self.timer:after(0.8, function() self:nextStage() end)
end
  

function AttackBasic:exit()
  self.main_class:changeStates()
  self.main_class.current_attack = nil
end

function AttackBasic:update(dt)
  if self.stages[self.current_stage].exit_condition then
    if self.stages[self.current_stage].exit_condition() then self:nextStage() end
  end

  if self.stages[self.current_stage].update then
    self.stages[self.current_stage].update()
  end
  self.timer:update(dt)
end

return AttackBasic