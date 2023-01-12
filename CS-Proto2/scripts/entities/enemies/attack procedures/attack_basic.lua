Object = require "libs.classic.classic"
Timer = require "libs.hump.timer"

AttackBase = require "scripts.entities.enemies.enemy_attack_base"

AttackBasic = AttackBase:extend()

function AttackBasic:new(main_class)
  self.main_class = main_class
  self.target = vector(0, 0)
  self.attack_direction = nil
  self.hop_height = {y = 0}
  self.attack_anim_duration = {d = 0.1}
  
  self.hitbox = nil
  
  -- this stuff you have to implement in each subclass
  self.current_stage = 1
  self.stages = {
    {enter = function() self:stage1() end, 
     --exit_condition = function() local distance = (self.main_class.pos.y - self.target.y) * self.target_mod return self.main_class.pos.y < self.target.y + 1 and self.main_class.pos.y > self.target.y - 1 end},
     exit_condition = function() local distance = (self.main_class.pos.y - self.target.y) * self.target_mod return distance > 0 end},
    {enter = function() self:stage2() end},

    {enter = function() self:stage3() end,
     update = function() self.main_class.Anim:changeSpeed(self.attack_anim_duration.d) end},
   
    {enter = function() self:stage4() end,
     update = function() self.main_class.Anim:changeSpeed(self.attack_anim_duration.d) end},
    
    {enter = function() self:exit() end}
  }

  self.timer = Timer.new()
  self.stages[self.current_stage].enter()
end

-- getting in line with the quarry
function AttackBasic:stage1()
  self.attack_direction = self.main_class.quarry_is_to
    
  self.main_class.following_quarry = false
  self.main_class.facing_quarry = false
  self.target = vector(self.main_class.quarry.pos.x + (100 * -self.attack_direction), self.main_class.quarry.pos.y)

  local target_distance = (self.target.y - self.main_class.pos.y)
  
  -- target_mod: tells whether the enemy is above or below target position
  self.target_mod = target_distance == 0 and 0 or target_distance / math.abs(target_distance)

  
  local toward_target = self.target - self.main_class.pos
  toward_target = toward_target:normalizeInplace()
  self.main_class.Move:setMovementSettings(toward_target, nil, 4, 0.09, 150) 
  --This stage should end when the enemy is lined up with the quarry as defined in the exit condition, but in the case that doesn't happen, this timer will end it the attack.
  self.timer:after(3, function() self:nextStage() end)
  -- skips this stage if the enemy is already roughly in line with the quarry
  if math.abs(target_distance) < 0.5 then self:nextStage() end
end

-- wind up 
function AttackBasic:stage2()
  self.timer:clear()
  self.main_class.Move:setMovementSettings(nil, vector(110 * -self.attack_direction, 0), 0, 0.4, 300)
  self.main_class.Anim:switchAnimation('attack_windup')
  self.timer:after(0.5, function() self:nextStage() end)
end

-- thrust forward
function AttackBasic:stage3()
  self.main_class.Anim:switchAnimation('attack') 
  local hitbox = self.main_class.collision_world:circle(self.main_class.pos.x + (30 * self.attack_direction), self.main_class.pos.y, 20)
  self.hitbox = self.main_class:addAttackCollider(hitbox, "EnemyAttack", function() return self.main_class.pos.x + (30 * self.attack_direction), self.main_class.pos.y end, 15, 0.1, 1700) 
  self.main_class.Move:defaultMovementSettings() 
  self.main_class.Move:setMovementSettings(vector(self.attack_direction, 0), nil, 50, 0.3, 140)

  local number_of_hops = 0
  local hop_peak = 10
  local hop_duration = 0.18
--[[
  local up, down
  up = function() self.timer:tween(hop_duration, self.hop_height, {y = hop_peak}, 'out-quart', function() hop_peak = hop_peak - 4 hop_duration = hop_duration - 0.04 down() end) end
  down = function() self.timer:tween(hop_duration, self.hop_height, {y = 0}, 'in-quart', function() number_of_hops = number_of_hops + 1 if number_of_hops >= 3 then self:nextStage() else up() end end) end]]
  --down = function() self.timer:tween(0.12, self.hop_height, {y = 0}, 'in-quart', function() self:nextStage() end) end
  self.main_class:jumpSeries(0.18, 10, 'quad', 
    function() self:nextStage() end,
    function(jump_num, dur) return dur - 0.03 end, 
    function(jump_num, hei) return hei - 2.5 end,
  3)
  self.timer:tween(0.3, self.attack_anim_duration, {d = 0.02}, 'in-linear')
end

--slide afterwards
function AttackBasic:stage4()
  self.main_class:removeCollider(self.hitbox)
  self.main_class.Move:setMovementSettings(nil, nil, 0, 0.3, nil)
  self.timer:after(0.8, function() self.main_class:changeStates('alerted') end)
  self.timer:tween(0.8, self.attack_anim_duration, {d = 0.1}, 'in-linear')
end
  
function AttackBasic:exit()
  if self.hitbox then self.main_class:removeCollider(self.hitbox) end
  self.main_class.current_attack = nil
  self.main_class:cancelHeightTween()
  self.main_class.height = 0
end

return AttackBasic