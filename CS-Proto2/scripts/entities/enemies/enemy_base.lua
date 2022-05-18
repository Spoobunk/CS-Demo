Object = require "libs.classic.classic" 
vector = require "libs.hump.vector"

Entity = require "scripts.entities.entity_base"

enemy_base = Entity:extend()

-- specific enemy classes should call this through the super keyword
function enemy_base:new(x, y, collision_world) 
  self.pos = vector(x, y)
  self.toward_player = vector(0, 0)
  self.collision_world = collision_world
end

function enemy_base:update(dt, player_pos)
  self.toward_player = player_pos - self.pos
end

function enemy_base:GetRenderPosition()
  error('subclasses should override enemy_base\'s getRenderPosition() function')
end

function Player_Anim:Get_Draw_Offset(frameWidth, frameHeight)
  -- either calculations work, just testing to see if it would smooth the movement when the camera is zoomed, seems no difference
  local offsetY = math.ceil(self.current_ground_level  - self.image_offset.y)
  local offsetX = math.ceil(frameWidth/2) - 1
  return offsetX, offsetY
end  

return enemy_base