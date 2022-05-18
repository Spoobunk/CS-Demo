Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'

ETAnim = Object:extend()

function ETAnim:new()
  self.et_sheet = love.graphics.newImage('assets/test/sprites/enemy test sheet.png')
  local walk_grid = anim8.newGrid(57, 75, self.et_sheet:getWidth(), self.et_sheet:getHeight(), 0, 0, 2)
  local attack_grid = anim8.newGrid(97, 75, self.et_sheet:getWidth(), self.et_sheet:getHeight(), 1, 79, 2)
  local idle_grid = anim8.newGrid(47, 78, self.et_sheet:getWidth(), self.et_sheet:getHeight(), 235, 0, 2)
  self.anims = {}
  self.anims.walk = anim8.newAnimation(walk_grid('1-4', 1), .5)
  self.anims.walk.ground_level = 75
  self.anims.attack = anim8.newAnimation(attack_grid('1-4', 1, '1-2', 2), .5)
  self.anims.attack.ground_level = 75
  self.anims.idle = anim8.newAnimation(idle_grid('1-2', 1), .5)
  self.anims.idle.ground_level = 78
  self.current_anim = self.anims.walk
  self.current_ground_level = self.current_anim.ground_level
  -- just half of the width and heights of the idle animation's frame size
  self.image_offset = vector(math.floor(47 / 2), 23)
end

function ETAnim:Get_Draw_Offset(frameWidth, frameHeight)
  -- the below line is basically pushing the sprite up so that the ground level (as defined by me) is at the actual y-position of the enemy, then pushing it down by an arbitrary offset value so that the feet always stay in the same place relative to the actual position of the enemy.
  local offsetY = math.ceil(self.current_ground_level  - self.image_offset.y)
  local offsetX = math.ceil(frameWidth/2) - 1
  return offsetX, offsetY
end  

function ETAnim:update(dt)
  self.current_anim:update(dt)
end

function ETAnim:draw(x,  y)
  local offsetX, offsetY = self:Get_Draw_Offset(self.current_anim:getDimensions())
  self.current_anim:draw(self.et_sheet, x, y, 0, 1, 1, offsetX, offsetY)
end

function ETAnim:addAnimation(name, anim_object)
  if(not self.anims[name]) then
    self.anims[name] = anim_object
  else
    error(("Attempted to add a duplicate animation to an entity, animation name: %s"):format(name))
  end
end

function ETAnim:switchAnimation(new_anim)
  if(self.anims[new_anim]) then
    self.current_anim = self.anims[new_anim]
    self.current_ground_level = self.current_anim.ground_level
    return true
  else
    error(("Attempted to switch to the non-existant animation, %s, on entity {entity code}"):format(new_anim))
  end
end

function ETAnim:getCurrentAnim()
  return self.current_anim
end

function ETAnim:getBaseImageOffset()
  return self.image_offset
end

return ETAnim
