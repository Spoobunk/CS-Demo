Object = require "libs.classic.classic"

AttackBasic = Object:extend()

function AttackBasic:new(main_class)
  self.main_class = main_class
  self.target = vector(0, 0)
  self:enter()
end

function AttackBasic:enter()
  main_class.following_player = false
  self.target = vector(main_class.player.position.x + 10, main_class.player.position.y)
  local toward_target = target - main_class.pos
  toward_target = toward_target:normalizeInplace()
  main_class.Move:setMovementSettings(toward_target)
end


function AttackBasic:update(dt)
  
end