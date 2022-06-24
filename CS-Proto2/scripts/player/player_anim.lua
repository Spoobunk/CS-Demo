Object = require "libs.classic.classic"
anim8 = require 'libs.anim8.anim8'
vector = require "libs.hump.vector"
luna = require "libs.lunajson.src.lunajson"

utilities = require 'scripts.utilities'

Player_Anim = Object:extend()

-- TODO: make it so only a set of anims are exposed that make sense for the player's current state
function Player_Anim:new()
  self.image_offset = vector(30 / 2, 52 / 2)
  self.current_ground_level = 0
  self.current_center_position = 0
  -- indicates whether the current animation should be flipped horizontally based on horizontal_flip
  self.current_do_flip = false
  -- indicates whether the current animation should be flipped horizontally
  self.horizontal_flip = false
  -- movement
  local player_run_sheet = love.graphics.newImage('assets/basic/sprites/player/player_run.png')
  local g = anim8.newGrid(34, 50, player_run_sheet:getWidth(), player_run_sheet:getHeight(), 0, 0, 1)
  local player_stand_sheet = love.graphics.newImage('assets/basic/sprites/player/player_idle_good.png')
  local g2 = anim8.newGrid(30, 51, player_stand_sheet:getWidth(), player_stand_sheet:getHeight(), 0, 0, 1)
  local big_test = love.graphics.newImage('assets/test/sprites/stuba center test.png')
  local g3 = anim8.newGrid(70, 104, big_test:getWidth(), big_test:getHeight(), 0, 0, 1)
  local attack_atlas = love.graphics.newImage('assets/basic/sprites/player/attack/attack-sheet.png')
  local attack_grid = self:Create_Grid('attack', 'mash')
  
  self.anim_sets = {
    {
      sheet = player_run_sheet,
      --draw_offset = self:Get_Draw_Offset(34, 50), 
      ground_level = 51,
      center_position = 17,
      do_flip = false,
      walk_down = anim8.newAnimation(g('1-4', 1), .13),
      walk_downright = anim8.newAnimation(g('5-6', 1, '1-2', 2), .13),
      walk_right = anim8.newAnimation(g('3-6', 2), .13),
      walk_upright = anim8.newAnimation(g('1-4', 3), .13),
      walk_up = anim8.newAnimation(g('5-6', 3, '1-2', 4), .13),
      walk_upleft = anim8.newAnimation(g('3-6', 4), .13),
      walk_left = anim8.newAnimation(g('1-4', 5), .13),
      walk_downleft = anim8.newAnimation(g('5-6', 5, '1-2', 6), .13),
    },
    {
      sheet = player_stand_sheet,
      --frame_size = self:Get_Draw_Offset(30, 51), 
      ground_level = 51,
      center_position = 15,
      do_flip = false,
      stand_down = anim8.newAnimation(g2(1,1, 1,3, 1,1, 1,3), {4, .1, .3, .1}),
      stand_downright = anim8.newAnimation(g2(2,1, 2,3, 2,1, 2,3), {4, .1, .3, .1}),
      stand_right = anim8.newAnimation(g2(3,1, 3,3, 3,1, 3,3), {4, .1, .3, .1}),
      stand_upright = anim8.newAnimation(g2(4,1), 1),
      stand_up = anim8.newAnimation(g2(1, 2), 1),
      stand_upleft = anim8.newAnimation(g2(2, 2), 1),
      stand_left = anim8.newAnimation(g2(3,2, 4,3, 3,2, 4,3), {4, .1, .3, .1}),
      stand_downleft = anim8.newAnimation(g2(4,2, 1,4, 4,2, 1,4), {4, .1, .3, .1}),
    },
    {
      sheet = attack_atlas,
      ground_level = 72,
      center_position = 73,
      do_flip = true,
      --attack = anim8.newAnimation(attack_grid('1-3', 1, '1-3', 2, '1-2', 3), .5)
      mash1 = anim8.newAnimation(attack_grid('1-3', 1), {.02, .06, .08}, 'pauseAtEnd'),
      mashready2 = anim8.newAnimation(attack_grid(4, 1), 1, 'pauseAtEnd'),
      mash2 = anim8.newAnimation(attack_grid('1-3', 2), {.02, .06, .08}, 'pauseAtEnd'),
      mashready3 = anim8.newAnimation(attack_grid(4, 2), 1, 'pauseAtEnd'),
      mash3 = anim8.newAnimation(attack_grid('1-2', 3, 3, 1), {.02, .06, .08}, 'pauseAtEnd')
    },
    {
      sheet = big_test,
      ground_level = 103,
      center_position = 0,
      anim_test = anim8.newAnimation(g3(1, 1), 1)
    }
  }
  
  self.idle_anim = 'stand_up'
  self.walk_anim_matrix = {
    {'walk_upleft', 'walk_up', 'walk_upright'},
    {'walk_left', Get_Current_Idle, 'walk_right'},
    {'walk_downleft', 'walk_down', 'walk_downright'}
  }
  self.idle_anim_matrix = {
    {'stand_upleft', 'stand_up', 'stand_upright'},
    {'stand_left', 'stand_down', 'stand_right'},
    {'stand_downleft', 'stand_down', 'stand_downright'}
  }
 

  self.current_sheet = self.anim_sets[2].sheet
  self.current_anim = self.anim_sets[2].stand_down
end

function Player_Anim:Get_Draw_Offset(frameWidth, frameHeight)
  -- either calculations work, just testing to see if it would smooth the movement when the camera is zoomed, seems no difference
  local offsetY = self.current_ground_level  - self.image_offset.y
  --local offsetX = math.ceil(frameWidth/2) - 1
  local offsetX = 0
  if self.horizontal_flip then
    offsetX = frameWidth - self.current_center_position
  else
    offsetX = self.current_center_position
  end
  --local offsetY = math.floor((self.current_ground_level  - self.image_offset.y) + 0.5)
  --local offsetX = math.floor((frameWidth/2) + 0.5)
  return offsetX, offsetY
end  

function Player_Anim:Get_Current_Idle()
  return self.idle_anim
end

function Player_Anim:Create_Grid(atlas_name, sheet_name)
  --[[
  local atlas_json = io.open('assets/basic/sprites/player/' .. atlas_name .. '/' .. atlas_name .. '-sheet.json', "r")
  local atlas_jsonraw = json:read("*all")
  local jsonparse = luna.decode(jsonraw)
  ]]
  local atlas_json = utilities.readFromJson('assets/basic/sprites/player/' .. atlas_name .. '/' .. atlas_name .. '-sheet.json')
  
  local atlas_size = atlas_json['meta']['size']
  local sheet_pos = atlas_json['frames'][atlas_name .. '-' .. sheet_name .. '.png']['frame']
  --local sheet_pos = atlas_json[atlas_name .. '-' .. sheet_name]
  local sheet = atlas_json['meta']['size']
  
  local sheet_json = utilities.readFromJson('assets/basic/sprites/player/' .. atlas_name .. '/' .. atlas_name .. '-' .. sheet_name .. '.json')
  local frame_size = sheet_json['frames'][1]['frame']
  
  --if not frame_size then error("animation you are trying to set up doesn't exist, ya barrel of monkeys!")
  local grid_boy = anim8.newGrid(frame_size['w'], frame_size['h'], atlas_size['w'], atlas_size['h'], sheet_pos['x'], sheet_pos['y'], 0)
  return grid_boy
end

function Player_Anim:flipSpriteHorizontal(face_direction)
  if face_direction ~= 0 then self.horizontal_flip = face_direction < 0 end
  --self.current_anim:flipH(face_direction)
end

function Player_Anim:Switch_Animation(new_anim)
  --self.current_sheet = self[category].sheet
  --self.current_anim = self[category][new_anim]
  --self.walk_anim_matrix[2][2] = self.idle_anim
  --print(self.idle_anim)
  for _, v in ipairs(self.anim_sets) do
    if(v[new_anim]) then
      if self.current_anim == v[new_anim] then return false end
      self.current_anim = v[new_anim]
      self.current_sheet = v.sheet
      self.current_ground_level = v.ground_level
      self.current_center_position = v.center_position
      self.current_do_flip = v.do_flip
      self.current_anim:gotoFrame(1)
      self.current_anim:resume()
      return true
    end
  end
  error(("Attempted to switch to the non-existant animation, %s"):format(new_anim))
end

function Player_Anim:update(dt)
  self.current_anim:update(dt)
end

function Player_Anim:draw(x, y)
  local offsetX, offsetY = self:Get_Draw_Offset(self.current_anim:getDimensions())
  if self.current_do_flip then
    self.current_anim:flipH(self.horizontal_flip):draw(self.current_sheet, x, y, 0, 1, 1, offsetX, offsetY)
  else
    self.current_anim:draw(self.current_sheet, x, y, 0, 1, 1, offsetX, offsetY)
  end
end

function Player_Anim:drawFrameBox(x, y)
  local offsetX, offsetY = self:Get_Draw_Offset(self.current_anim:getDimensions())
  local w, h = self.current_anim:getDimensions()
  love.graphics.rectangle('line', x - offsetX, y - offsetY, w, h)
end

function Player_Anim:Get_Base_Image_Offset()
  return self.image_offset
end

function Player_Anim:Get_Current_Animation()
  return self.current_anim
end

function Player_Anim:Get_Current_Sheet()
  return self.current_sheet
end

function Player_Anim:Get_Frame_Dimensions()
  return self.current_anim:getDimensions()
end
  

return Player_Anim