Object = require "libs.classic.classic"
vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"

utilities = require 'scripts.utilities'

Hand = Object:extend()

local vertexcode = [[
varying float depth;

#ifdef VERTEX
attribute float SegmentDepth;

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    depth = SegmentDepth;
    if(SegmentDepth == 1) {
      //VaryingColor = vec4(0,0,0,0);
      //depth = 2;
    }
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
// this uniform decides which segments to draw based on their depth. If drawOrder is -1, then only vertices with a depth of 0 will be drawn. If drawOrder is 1, then only vertices with a depth above 0 will be drawn.
uniform float draw_order;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    vec4 texcolor = Texel(tex, texture_coords);
    
    if(draw_order < 1){
      // when drawing behind the player, don't draw segments that have a depth greater than 0
      if(depth > 0.5){ color = vec4(0,0,0,0); }
    }else{
      // when drawing in front of the player, don't draw segments that have a depth of 0
      if(depth < 0.5){ color = vec4(0,0,0,0); }
    }
    return texcolor * color;
}
#endif
]]

shader = love.graphics.newShader(vertexcode)

function Hand:new(state_manager, segments)
  self.state_manager = state_manager
  self.segments = segments or 40
  
  -- this is the position of the first vertex in the arm relative to the player's position. All other vertices are relative to this position.
  self.arm_origin = vector(0,0)
  
  -- this table contains vectors, each representing the position of a joint in the arm. each position vector is interpreted as being relative to the previous joint in the series. The vectors are in polar coordinates, with x being the angle and y being the length of the position vector.
  -- the choice of polar coordinates was made because in most cases when dealing with the idea of an arm with several joints, this format is more convenient
  self.joints = {}
  self.joint_depths = {}
	self.joint_colors = {}
  
  -- the normal legnth of each segment that makes up the arm. Each segment can define their own length in the joints table, but this is used as the standard
  self.standard_segment_length = 8.5
	
	-- fills the self.joints table
	for i=1, self.segments do
    local angle = 0

    local vertex = vector(angle, self.standard_segment_length)
    table.insert(self.joints, vertex)
    table.insert(self.joint_depths, 1) 
	end
  
  local vertex_format = {
    {"VertexPosition", "float", 2}, -- The x,y position of each vertex.
    {"VertexTexCoord", "float", 2}, -- The u,v texture coordinates of each vertex.
    {"VertexColor", "byte", 4}, -- The r,g,b,a color of each vertex.
    {"SegmentDepth", "float", 1} -- Used to determine whether an arm segment is drawn above or below the player.
  }
	
  -- this variable holds the table of vertices used to construct the mesh that's being used currently. We save it here so that we can create an after image with the same vertices. We save the table to a variable rather than calling getVertices() on the mesh because that method is slow, and it's advised to just keep a copy of the vertices instead (from the love2d documentation) 
  self.current_vertices = self:jointsToVertices(self.joints, 0)
  self.end_arm_pos = self:jointsToPlayerCoordinates(self.joints)[#self.joints]
	self.mesh = love.graphics.newMesh(vertex_format, self.current_vertices, "strip")

  -- the angle that is used to calculate the position of the joints in the cannedSwing() method
  self.angle = math.rad(-90)
  
  self.swinging = true
  self.swing_direction = 1
  -- this value is the angle of the first joint in the arm
  self.arm_angle = math.rad(-90)
  -- the speed of the the increase of arm_angle
  self.arm_speed = 0
  self.angle_speed = 0
  -- controls whether afterimages are drawn or not
  self.showing_afterimages = false
  --self.afterimage_angle = 0
  --self.afterimage_arm_angle = 0
  -- number between 0 and 1, used to control the size of afterimages
  self.current_swing_speed = 0
  self.angle_timer = Timer:new()
  
  self.test_hold_pos = vector(0,0)
  self.test_hold_seg = vector(0,0)
  
  --self:testSwingMotion(1)
  self:testDepth()
  self.noodle = 0

  self.num_of_afterimages = 25
  -- afterimage_meshes is a table that holds a static number of meshes that are used as afterimages
  self.afterimages = {}
  for i=1, self.num_of_afterimages do
    table.insert(self.afterimages, love.graphics.newMesh(vertex_format, self.current_vertices, "strip"))
  end
  
  -- this stuff is used in the spikySmearAfterimage() i was testing out. I'll leave it here just in case
  --[[self.test_afterimage_vertices = 11
  self.test_afterimages = {}
  local verts = {}
  for i=1,self.test_afterimage_vertices*2 do
    verts[i] = {0,0}
  end
  for i=1, math.floor(#self.joints - 1) do
    self.test_afterimages[i] = love.graphics.newMesh(verts, "strip")
  end]]
end

function Hand:update(dt)
  self.angle_timer:update(dt)

  if self.swinging then 
    --self.angle = self.angle + (0.1 * dt) * 10

    self:updateArmVertices(self:cannedSwing(self.angle, dt))
    self:updateAfterimages(dt)
    self.arm_angle = self.arm_angle + self.arm_speed
    self.angle = self.angle + (self.angle_speed*dt)
  else
    self:updateArmVertices(self.joints, 0, self.joint_depths, self.joint_colors)
    --self:updateAfterimages(dt)
  end
end

function Hand:updateAfterimages(dt)
  local current_joints = utilities.deepCopy(self.joints)
  local orig_joint_angle = current_joints[1].x
  --local current_joints = self:cannedSwing(self.afterimage_angle, dt)
  --local orig_joint_angle = self.afterimage_arm_angle
  local swing_speed = 1 - math.abs(math.sin(self.angle))
  
  for i,mesh in ipairs(self.afterimages) do
    local aftimg_range = ((self.num_of_afterimages + 1) - i)
    local arm_angle_offset = math.min(aftimg_range * math.rad(3) * self.current_swing_speed, aftimg_range * math.rad(10))
    local angle_offset = aftimg_range * math.rad(5) * self.current_swing_speed

    --local vertices = self:jointsToVertices(self:cannedSwing(self.angle - (angle_offset*self.swing_direction), dt))
    --[[
    local new_angle = math.max(math.min(self.angle - (angle_offset*self.swing_direction), math.rad(90)), math.rad(-90))
    local new_joints = self:cannedSwing(new_angle, dt)
    new_joints[1] = vector(orig_joint_angle + (-arm_angle_offset*self.swing_direction), new_joints[1].y)
    local vertices = self:jointsToVertices(new_joints, 1)
    ]]
    current_joints[1] = vector(orig_joint_angle + (-arm_angle_offset*self.swing_direction), current_joints[1].y)
    local vertices = self:jointsToVertices(current_joints, 1)
    
    -- translates the index of this afterimage to a range from 0 (furthest afterimage) to 1 (closest afterimage).
    local afterimage_range = (i-1) / (self.num_of_afterimages-1)
    
    for j=1, #vertices do
      -- red
      vertices[j][5] = 1 - (afterimage_range * 0.2)
      -- green
      vertices[j][6] = afterimage_range * 0.5 + 0.4
      -- blue
      vertices[j][7] = afterimage_range * 0
      -- alpha
      vertices[j][8] = afterimage_range * 0.6 + 0.35
      --vertices[j][8] = 1
    end

    mesh:setVertices(vertices)
  end
end

-- this is a function I wrote to give the hand swing a spiky smear effect. But the end result doesn't look that great, and the function goes through a lot of loop iterations every frame, so I'd rather not use it.
function Hand:spikySmearAfterimages(dt)
  local current_joints = utilities.deepCopy(self.joints)
  local orig_joint_angle = current_joints[1].x
  local swing_speed = 1 - math.abs(math.sin(self.angle))
  
  for j=2, math.floor(#self.joints - 1) do
    local afterimage_vertices = {}
    for i=1, self.test_afterimage_vertices do
      -- range from 10 (first loop) to 0 (last loop)
      local aftimg_range = ((self.test_afterimage_vertices) - i)
      --local angle_offset = math.min(aftimg_range * math.rad(3) * self.current_swing_speed, aftimg_range * math.rad(10))
      local angle_offset = aftimg_range * math.rad(5) * self.current_swing_speed

      --local vertices = self:jointsToVertices(self:cannedSwing(self.angle - (angle_offset*self.swing_direction), dt))
      current_joints[1] = vector(orig_joint_angle + (-angle_offset*self.swing_direction), current_joints[1].y)
      local vertices = self:jointsToVertices(current_joints, 1)
      
      -- casting the last joint in current_joints back into a polar vector (the deepCopy function turns it into a normal table)
      local vertex_index = j * 2 + 1

      local last_joint = vector(current_joints[j].x, current_joints[j].y)
      -- converting the vector from polar to normal
      last_joint = vector.fromPolar(last_joint:unpack())
      local first_vertex = vector(unpack(vertices[vertex_index]))
      local prev_vertex = vector(unpack(vertices[vertex_index-2]))
      local vertex_range = ((i-1) / (self.test_afterimage_vertices-1))
      local second_vertex_dir = (first_vertex - prev_vertex):normalizeInplace()
      local second_vertex = first_vertex - (second_vertex_dir * (70*vertex_range*math.abs(self.current_swing_speed)))
      
      second_vertex = {second_vertex.x, second_vertex.y, 0, 0, 1, 0, 0, 1}
      first_vertex = {first_vertex.x, first_vertex.y, 0, 0, 1, 1, 0.2, 1}

      table.insert(afterimage_vertices, first_vertex)
      table.insert(afterimage_vertices, second_vertex)
    end
    self.test_afterimages[j]:setVertices(afterimage_vertices)
  end
  
end

function Hand:testSwingMotion(dir)
  self.showing_afterimages = true
  self.arm_angle = math.rad(0)
  self.angle_timer:tween(8, self, {angle = math.rad(90)}, 'linear', function()
    self.swing_direction = -1
    self.angle_timer:tween(8, self, {angle = math.rad(-90)}, 'linear')
  end)
self.current_swing_speed = 1
self.angle_timer:tween(8, self, {current_swing_speed = 0}, 'linear')
end

function Hand:testDepth()
  self.swinging = false
  local joints = self.joints
  local arc_points = 6
  local halfway_point = arc_points/2
  -- this is where we save the depth of each arm segment to use when calling JointsToVertices later
  local segment_depths = {}
  local last_depth = 0

  for i=1, #joints do
    local arc_index = (i-1) % arc_points
    local joint_range = 1 - (math.abs(arc_index - halfway_point) / halfway_point)
    local new_angle = math.rad(110 * math.pow(joint_range, 3))
    local angle_sign = (i-1) % (arc_points*2) < arc_points and -1 or 1
    if joint_range == 1 then
      last_depth = last_depth == 0 and 1 or 0
    end
    segment_depths[i] = (i+halfway_point-1) % (arc_points*2) < arc_points and 0 or 1

    --print(math.deg(new_angle), joint_range, angle_sign, (i-1) % (arc_points*2))
    self.joints[i].x = angle_sign * new_angle
    self.joints[i].y = 30 * (1 - joint_range) + 2
  end
  self.joints[1].x = math.rad(0) + self.joints[1].x
  local vertices = self:jointsToVertices(self.joints, 0, segment_depths)
  self.joint_depths = segment_depths
  self.mesh:setVertices(vertices)
end

function Hand:rotate()
  self.joints[1].x = self.arm_angle
end

function Hand:swing(number, attack_direction)
  self.angle_timer:clear()
    self.swinging = true
  if number % 2 == 0 then 
    self.swing_direction = -1
  else
    self.swing_direction = 1
  end
  
  local starting_angle = attack_direction == 1 and 0 or 180
  local offset_direction = attack_direction + self.swing_direction == 0 and 1 or -1

  -- here we set the angles so that the arm appears to be partway through the swing immediatly. We do this because it makes the swing feel responsive
  self.arm_angle = math.rad(starting_angle + 20*offset_direction)
  self.angle = math.rad(-50*self.swing_direction*attack_direction)
  
  self.showing_afterimages = false
  
  local attack_duration = 0.07
  local resolve_duration = 0.29
  
  --self.angle_speed = (math.rad(starting_angle + 20*self.swing_direction) - self.angle) / (attack_duration)
  --self.angle_timer:tween(0.2, self, {angle_speed = 0}, 'linear')
  self.angle_timer:tween(attack_duration, self, {angle = math.rad(10*self.swing_direction*attack_direction)}, 'linear', function()
    self.angle_timer:tween(0.08, self, {angle = math.rad(30*self.swing_direction*attack_direction)}, 'linear', function()
      self.angle_timer:tween(0.3, self, {angle = math.rad(70*self.swing_direction*attack_direction)}, 'out-quad')
    end)
  end)

  self.angle_timer:tween(attack_duration, self, {arm_angle = math.rad(starting_angle + -135*offset_direction)}, 'out-quad', function()
      --self.angle_timer:tween(resolve_duration/3, self, {arm_angle = math.rad(starting_angle + -115*offset_direction)}, 'out-cubic')
  end)
  
  self.current_swing_speed = attack_direction 
  self.showing_afterimages = true
  self.angle_timer:after(0, function()
    self.angle_timer:tween(attack_duration, self, {current_swing_speed = 0.5*attack_direction}, 'linear', function()
      self.angle_timer:tween(0.04, self, {current_swing_speed = 0}, 'linear', function() 
        self.showing_afterimages = false
      end)
    end)
  end)
  --[[
  self.arm_speed = math.rad(30*self.swing_direction)
  self.angle_timer:after(0.05, function() 
      self.angle_timer:tween(0.3, self, {arm_speed = 0}, 'out-cubic')
  end)
  ]]
end  

function Hand:readySwing(number, attack_direction)
  self.angle_timer:clear()
  local dir = 1
  if number % 2 == 0 then 
    dir = -1
  end

  --self.showing_afterimages = false
  self.swing_direction = dir
  local starting_angle = attack_direction == 1 and 0 or 180
  local offset_direction = attack_direction + self.swing_direction == 0 and 1 or -1
  
  -- might get rid of this
  if number == 1 then
    self.swinging = true
    self.angle = math.rad(-90*self.swing_direction*attack_direction)
    self.arm_angle = math.rad(starting_angle + 135*offset_direction)
  end
  
  --self.angle = math.rad(starting_angle + -45*self.swing_direction)
  self.angle_timer:tween(0.1, self, {angle = math.rad(-90*self.swing_direction*attack_direction)}, 'linear')
  --self.angle_timer:tween(0.08, self, {arm_angle = math.rad(starting_angle + 130*offset_direction)}, 'linear')
end

function Hand:grabSwing(attack_direction)
  self.angle_timer:clear()
  self.swinging = true
  self.swing_direction = 1
  
  local starting_angle = attack_direction == 1 and 0 or 180
  local offset_direction = attack_direction + self.swing_direction == 0 and 1 or -1

  -- here we set the angles so that the arm appears to be partway through the swing immediatly. We do this because it makes the swing feel responsive
  self.arm_angle = math.rad(starting_angle + 70*offset_direction)
  self.angle = math.rad(-50*self.swing_direction*attack_direction)
  
  self.showing_afterimages = true
  
  self.angle_timer:tween(0.04, self, {arm_angle = math.rad(starting_angle + 30*offset_direction)}, 'linear', function()
    self.angle_timer:tween(0.08, self, {arm_angle = math.rad(starting_angle + -30*offset_direction)}, 'linear', function()
      self.angle_timer:tween(0.13, self, {arm_angle = math.rad(starting_angle + -70*offset_direction)}, 'linear')  
    end)
  end)
  
  self.angle_timer:tween(0.04, self, {angle = math.rad(-40*self.swing_direction*attack_direction)}, 'linear', function()
        self.angle_timer:tween(0.08, self, {angle = math.rad(20*self.swing_direction*attack_direction)}, 'linear', function()
    self.angle_timer:tween(0.3, self, {angle = math.rad(70*self.swing_direction*attack_direction)}, 'linear')  
    end)
  end)

  self.current_swing_speed = attack_direction
  self.angle_timer:tween(0.3, self, {current_swing_speed = 0}, 'linear')
  --[[
  self.arm_speed = math.rad(30*self.swing_direction)
  self.angle_timer:after(0.05, function() 
      self.angle_timer:tween(0.3, self, {arm_speed = 0}, 'out-cubic')
  end)
  ]]
end

function Hand:onGrab(attack_direction)
  self.angle_timer:clear()
  
  local starting_angle = attack_direction == 1 and 0 or 180
  local offset_direction = attack_direction + self.swing_direction == 0 and 1 or -1
  
  self.current_swing_speed = attack_direction
  --self.arm_angle = math.rad(starting_angle + -60*offset_direction)
  --self.angle = math.rad(50*self.swing_direction*attack_direction)
  self.angle_timer:tween(0.1, self, {arm_angle = math.rad(starting_angle + -70*offset_direction)}, 'out-quad')
  self.angle_timer:tween(0.1, self, {angle = math.rad(70*self.swing_direction*attack_direction)}, 'out-quad')
  self.angle_timer:tween(0.1, self, {current_swing_speed = 0}, 'linear')
  --self.swinging=false
  --self.showing_afterimages=false
  joints, depths = self:holdingPosition(vector(0, 1), vector(0,2))
  self.joint_depths = depths
  self.angle_timer:after(0.1, function() 
    self.swinging=false
    self.showing_afterimages=false
    for i=1,#self.joints do
      self.angle_timer:tween(0.2, self.joints[i], {x = joints[i].x}, 'out-cubic')
      self.angle_timer:tween(0.2, self.joints[i], {y = joints[i].y}, 'out-cubic')
    end
    --self:updateArmVertices(joints, 0, depths) 
  end)
end

-- when calling this function externally, we don't need to provide a second argument, since that argument is only used when the function calls itself for recursion.
function Hand:retractArm(time, segment)
  self.swinging = false
  --self.showing_afterimages = false
  local current_segment = segment or #self.joints
  local retract_duration = time / #self.joints
  --here, if the retract duration is low enough, then we skip the process of setting tweens and just set the lengths of every subsequent joint to 0, and return some value to stop the function for recurring.
  if retract_duration < 0.0001 then 
    for i=current_segment,1,-1 do
      self.joints[i].y = 0
    end
    return false
  end
  self.angle_timer:tween(retract_duration, self.joints[current_segment], {y = 0}, 'linear', function()
    if current_segment ~= 1 then
      self:retractArm(time * 0.5, current_segment - 1)
    end
  end)
end

function Hand:retracterBeam(time)
  self.swinging = false
  for i=1,#self.joints do
    self.angle_timer:tween(time, self.joints[i], {y=0}, 'linear')
  end
end

function Hand:changeHoldingPosition(face_direction, hold_pos)
  local joints, depths, colors = self:holdingPosition(face_direction, hold_pos)
  self.joint_depths = depths
  self.joint_colors = colors
  self:updateArmVertices(joints, 0, depths)
  --local angle = face_direction:normalized():angleTo(vector(0,1))
  
  --self.joints[1].x = joints[1].x + angle
  --self:updateArmVertices({})
end


-- @param {vector} face_direction The digital representation of the player's direction
function Hand:holdingPosition(face_direction, hold_pos)
  local return_joints = {}
  local joint_depths = {}
  local joint_colors = {}
  
  local face_dir = face_direction:normalized()
  -- the position of the held object relative to the player
  --local holding_pos = (face_dir * 50) + (-face_dir:perpendicular() * 30)
  --local holding_pos = (face_dir * 50) + vector(0,self.state_manager.base_height)
  -- converts the position vector to polar format (x: angle, y:distance)
  hold_pos = hold_pos:clone()
  local angle_range = math.abs(math.abs(math.deg(face_direction:angleTo())) - 90) / 90
  -- there are 12 values passed as parameters to the distanceArc function to create two arcs, each arc takes 6 parameters
  -- these parameters are used for the distanceArc function when the the player is facing horizontally.
  local horizontal_values = {0.4, 15, -1, 0, 1, 0.5, 0.6, 25, 1, -20, 0.7, 1}
  -- these parameters are used for the distanceArc function when the the player is facing vertically.
  local vertical_values = {0.5, 15, -1, 2, 0.7, 0.1, 0.5, 25, 1, -10, 1.6, 1}
  -- this table will hold the parameters we will actually use
  local use_values = {}
  for i=1, #horizontal_values do
    -- this interpolates between the horizontal and vertical values based on the angle of face_direction. when face_direction is at a 45 degree angle (moving diagonally) the values will be exactly halfway between either value.
    use_values[i] = vertical_values[i] - (vertical_values[i] - horizontal_values[i]) * angle_range
  end
  -- this angle is what all joint angles are relative to. It's added to the angle of the first joint to acheive this effect.
  local starting_angle = 0
  -- the angle of the first joint, relative to the starting angle
  local first_joint_angle = 0
  local target_angle = -90
  local arc_angles = {}
  --[[
  if face_direction == vector(1,0) then
    starting_angle = 20
    --arc_angles, joint_colors = self:jointArc(starting_angle, {-50, 15, 2, -135, 15, 2, -5, 80, 4, 110, 15, 3})
    arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.4, 4, -1, 0, 0.5, hold_pos.y * 0.6, 7, 1, -20, 0.5})
  elseif face_direction == vector(1,1) then
    starting_angle = 25
    --arc_angles, joint_colors = self:jointArc(starting_angle, {-50, 30, 4, -20, 35, 4, 140, 20, 3})
    arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.45, 4, -1, -1.5, 0.65, hold_pos.y * 0.55, 7, 1, -15, 0.85})
  elseif face_direction == vector(0,1) then
    starting_angle = 70
    --arc_angles, joint_colors = self:jointArc(starting_angle, {-70, 20, 4, 70, 30, 4, 140, 20, 3})
    arc_angles = self:distanceArc(hold_pos.x, {25, 20, -1, 5, 0.8, 25, 20, 1, -5, 1.2})
  elseif face_direction == vector(-1,1) then
    starting_angle = 45
    --arc_angles, joint_colors = self:jointArc(starting_angle, {-45, 200, 11})
    --arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y/2, 6, 1, 0, 1, hold_pos.y/2, 5, -1, 0, 1})
    arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.5, 4, -1, -1.5, 0.65, hold_pos.y * 0.55, 7, 1, -15, 0.85})
  elseif face_direction == vector(-1,0) then
    starting_angle = 100
    --arc_angles, joint_colors = self:jointArc(starting_angle, {135, 20, 2, 200, 20, 2, 230, 30, 4, 160, 20, 3})
    arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.4, 4, -1, 0, 0.5, hold_pos.y * 0.6, 7, 1, -20, 0.5})
  elseif face_direction == vector(-1,-1) then
    starting_angle = -135
    --arc_angles, joint_colors = self:jointArc(starting_angle, {-200, 20, 3, -160, 40, 4, -50, 45, 4})
    arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.5, 4, -1, -1.5, 0.65, hold_pos.y * 0.55, 7, 1, -15, 0.85})
  elseif face_direction == vector(0,-1) then
    starting_angle = -90
    --arc_angles, joint_colors = self:jointArc(starting_angle, {-180, 40, 4, -75, 55, 4, -20, 25, 3})
    arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.5, 4, -1, -3, 0.8, hold_pos.y * 0.5, 7, 1, -10, 1.2})
  elseif face_direction == vector(1,-1) then
    starting_angle = -25
    --arc_angles, joint_colors = self:jointArc(starting_angle, {-130, 20, 4, -120, 40, 3, 0, 60, 4})
    arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.5, 4, -1, -1.5, 0.65, hold_pos.y * 0.55, 7, 1, -15, 0.85})
  end
  ]]
  --return_joints[1] = vector(math.rad(starting_angle+first_joint_angle), 20)
  local arc_segments = (#self.joints-1)
  hold_pos = hold_pos:toPolar()
  arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * use_values[1], use_values[2], use_values[3], use_values[4], use_values[5], use_values[6], hold_pos.y * use_values[7], use_values[8], use_values[9], use_values[10], use_values[11], use_values[12]})
  --local arc1_angle = math.rad(45)
  --local arc1_distance = (hold_pos.y * 0.5) / math.cos(arc1_angle)
  self.test_hold_pos = hold_pos
  local arc1_end = (hold_pos:normalized() * hold_pos:len() * 0.3):rotateInplace(math.rad(-40))
  self.test_hold_seg = arc1_end
  local arc1, result_angle = self:distanceArc(-arc1_end:angleTo() + math.pi/2, {arc1_end:len(), 20, -1, 10, 1, 2})

  local arc2_end = hold_pos - arc1_end
  -- I really don't know why this works but I don't care
  local arc2_angle = arc2_end:angleTo(arc1_end) - math.rad(270)
  local arc2 = self:distanceArc((hold_pos.x + (-arc2_angle + math.pi/2)) - (hold_pos.x - result_angle), {arc2_end:len(), 20, 1, -20, 0.7, 0})
  --arc_angles = arc1
  for i=1,#arc2 do
    --table.insert(arc_angles, arc2[i])
  end

  --self.noodle = self.noodle - 0.2
  --local vertical_values = {0.5, 20, -1, 0, 0.8, 0.5, 20, 1, -10, 1.6}
  --arc_angles = self:distanceArc(-face_dir:angleTo() + math.pi/2, {100, 40, 1, 0, 1, self.noodle})
  --arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.4, 15, -1, 0, 1, 0.5, hold_pos.y * 0.6, 25, 1, -20, 0.7, 1})
  --arc_angles = self:distanceArc(hold_pos.x, {hold_pos.y * 0.5, 15, -1, 2, 0.7, 0.1, hold_pos.y * 0.5, 25, 1, -10, 1.6, 1})
  for i=1,#self.joints do
    local big_joint = arc_angles[i] and arc_angles[i] or vector(0,10)
    --print('go: ' .. big_joint.x)
    return_joints[i] = big_joint
  end
  for i=1,#return_joints do
    joint_depths[i] = 1
  end
  return return_joints,joint_depths,joint_colors
end

-- this method takes a table describing the shape of arcs and turns it into a table of joints with the shape described.
-- @param {number}(angle in degrees) starting_angle The angle that the arm starts at
--[[ @param {table} arcs A table describing the shape of an arc with this format:
  {target_angle, length, segments, ...} 
  {number} target_angle The angle you want the last joint in the arc to end up 
  {number} length The total length of the arc
  {number} segments To amount of segments that make up the arc
  ... You can provide as many arc definitions as you want. The function will only go up to the last complete arc definition; if there is one or two trailing entries in the table, they'll be ignored. 
  ]]
function Hand:jointArc(starting_angle, arcs)
  local return_joints = {}
  local return_colors = {}
  local last_angle = starting_angle
  for i=1,math.floor(#arcs/3) do
    local target_angle = arcs[i*3-2]
    local arc_length = arcs[i*3-1]
    local segments = arcs[i*3]

    local increment_angle = -math.rad(last_angle - target_angle) / segments
    local increment_length = arc_length / segments
    local joint_color = i % 2 > 0 and {1,0,0,1} or {0,0,1,1}
    for j=1,segments do
      -- for the first joint in the arm, we set the starting angle. Since each joint is relative to the last, setting the first joint this way will affect all subsequent joints
      if i==1 and j==1 then 
        table.insert(return_joints, vector(math.rad(starting_angle) + increment_angle, increment_length))
      else
        table.insert(return_joints, vector(increment_angle, increment_length))
      end
      table.insert(return_colors, joint_color)
    end
    last_angle = target_angle
  end
  return return_joints, return_colors
end

function Hand:distanceArc(starting_angle, arcs)
  --print(math.deg(starting_angle))
  local return_joints = {}
  --local increment_distance = distance / segments
  --local increment_angle = -math.rad(starting_angle - (80)) / (segments-1)
  local last_angle = starting_angle
  
  for i=1,math.floor(#arcs/6) do
    -- the distance you want the arc the cover in the direction of starting_angle
    local r = arcs[i*6-5]/2
    -- how many segments make up the arc
    local segments = arcs[i*6-4]
    -- either 1 or -1, decides what side of the target line the arc will be on
    local side = arcs[i*6-3]
    -- a number that effects the radius of each arc point, bending the arc in weird ways
    local bend = arcs[i*6-2]
    -- how much you want to squash or stretch the arc.
    local squash = arcs[i*6-1]
    -- a small value around 1 that makes the end of the arc less steep. a value of 0 doesn't do anything, and negative values make an insane lightning bolt effect.
    local smooth = arcs[i*6]

    -- the position of the last arc point in the series. initialized to the position of the arc when then angle is 0.
    local last_arc_point = vector(r,0)
    for i=1,segments do
      local range = (i) / (segments)
      --local distance_mod = 1 - math.sin(math.pi/2 + (range * 2 * math.pi/2)) * 1.5
      --local line_segment = increment_distance * distance_mod
      --local joint_distance = increment_distance / math.cos(last_angle)
      
      --print('lol: ' .. math.deg(vector(current_width, current_height):toPolar().x))
      local joint_height = math.sin(range * math.pi) * 20
      --local r = 25
      --local bend = 50
      --local x = math.abs(math.abs(1 - (range * 2)) - 1) * (math.pi/2)
      --print(math.abs(math.abs(1 - (range * 2)) - 1))
      --local mod_r = math.abs(math.abs(1 - (range * 2)) - 1) * 0 + r
      local mod_r = r
      mod_r = -(1 - (range * 2)) * bend + r
      local smooth_magnitude = -r / 2
      --mod_r = math.pow(math.abs(math.abs((range * 2) - 1) - 1), 0.5) * -100 + mod_r
      mod_r = math.sin(math.pow(1-range, smooth * (1-range)) * math.pi) * smooth_magnitude + mod_r
      
      --print(mod_r)
      --print(1 - (range * 2))
      local x = range * math.pi
      --[[
      local apex_rad = math.sqrt(10^2 + r^2)
      local apex_angle = math.acos(50/apex_rad)
      local rad_dif = apex_rad - r
      local apex_dif = math.pi - apex_angle
      -- should be 1 at when x = 180
      local apex_range = math.abs(x - apex_angle) / apex_dif
      local mod_r = r + (rad_dif * (1 - apex_range))
      ]]
      --mod_r = (new_adj/math.cos(x))
      --print(new_adj/math.cos(x))
      --print(math.deg(x))

      -- the position of the current point in the arc
      local arc_point = vector(math.cos(x) * mod_r, math.sin(x) * mod_r)
      
      joint_height = arc_point.y - last_arc_point.y
      last_arc_point.y = last_arc_point.y + joint_height
      --joint_height = (math.tan(x)) * 50
   
      --joint_height = joint_height - current_height 
      --local joint_width = (r-bend) - (current_width + adj)
      --current_width = current_width + joint_width
      
      local joint_width = (last_arc_point.x - bend) - arc_point.x
      last_arc_point.x = last_arc_point.x - joint_width
      
      --print(current_width)
      --print(joint_width)
      --joint_width = math.max(joint_width, 0)
      --print(joint_width)
      
      --print(current_height)
      --print(line_segment ..  " / " .. joint_distance .. " = " .. line_segment/joint_distance)
      --[[
      if i==1 then
        table.insert(return_joints, vector(math.rad(starting_angle), joint_distance))
      else
        table.insert(return_joints, vector(increment_angle, joint_distance))
      end
      ]]
      --print(vector(joint_height, joint_width).y)
      --print(utilities.ellipsify(vector(joint_height, joint_width)).y)
      -- here is where we squash or stretch the arc using the ellipsify function
      joint_height = utilities.ellipsify(vector(joint_width, joint_height), squash).y
      this_joint = vector(joint_width, joint_height * side):toPolar()
      --print(math.deg(this_joint.x))
      this_joint.x = this_joint.x - last_angle
      last_angle = this_joint.x + last_angle
      --print('huhh :' .. math.deg(this_joint.x))
      --print(math.deg(last_angle) .. " - " .. math.deg(this_joint.x))
      table.insert(return_joints, this_joint)
      --last_angle = last_angle + increment_angle
    end
  end
  return return_joints, last_angle
end

function Hand:cannedSwing(angle, dt)
  -- the list of joints to return
  local return_joints = {}
  -- The first vertex is at the origin (0, 0) and the point where the arm connects with the player
	--table.insert(vertices, vector(0, 0))
  local last_angle = angle
  local swing_angle = math.rad(0)
  local MAX_ANGLE = math.rad(200 / (#self.joints-1)) -- the maximum angle between vertices
  local SLAP_SPEED = 1 -- controls how fast the middle of the slap motion is compared to the beginning and end of the motion
  local angle_offset = MAX_ANGLE
  -- the length of the entire arm
  local arm_length = 85
  
  -- this range is used to modify the angle offset so that by the time the angle is such that the first vertex is horizontally aligned with the player, then the angle offset will become 0 and all vertices will be horizontally aligned. 
  -- since math.sin already returns a normalized value, we don't have to math.min anything
  local angle_dif = math.sin(angle)
  -- here we store the sign of angle_dif to apply later
  local angle_sign = utilities.sign(angle_dif)
  -- here we invert the range of angle_dif and raise it to a power, so that the effect of the arm straightening out is non-linear.
  angle_dif = math.pow(1 - math.abs(angle_dif), SLAP_SPEED) 
  -- now we invert angle_dif again so that it has the desired effect on angle_offset.
  angle_offset = angle_offset * ((1-angle_dif) * angle_sign)

  local swing_dif = angle_sign < 1 and (1-angle_dif) * math.rad(-180) or (1-angle_dif) * math.rad(45)
  --return_joints[1] = vector(swing_angle + swing_dif, self.standard_segment_length)
  return_joints[1] = vector(self.arm_angle, arm_length / (#self.joints-1))
  
  for i=2, #self.joints do
    -- range from 0 (second joint) to 1 (last joint)
    local joint_range = (i-2) / (#self.joints-2)
    -- the maximum angle this specific joint can have. The further the joint is along the arm, the smaller the maximum angle
    local joint_max_angle = MAX_ANGLE - (joint_range * math.rad(100 / (#self.joints-1)))
    -- range from 0 (near the extents of the swing) to 0.3 (near the middle of the swing)
    -- these two magic numbers are fun to play around with
    local speed_range = ((angle_dif * 3) * (joint_range * 0.5)) + 1
    --local speed_range = angle_sign < 0 and angle_dif * 0.25 or angle_dif * -0.25
    
    -- this makes it so the angle of each joint lessens as it goes up the arm, giving the arm a sense of stiffness instead of being curved in a perfect circle
    angle_offset = math.min(math.max(angle_offset, -joint_max_angle), joint_max_angle)
    -- this makes it so joints further up the arm don't move as fast as joints close to the origin, adding a bit of secondary motion to the arm
    --angle_offset = angle_offset * math.min(speed_range, 1.2)
    --angle_offset = angle_offset * speed_range
    
    -- this makes it so the secondary motion effect doesn't happen at the end of the swing, because that effect only looks right at the start of a swing.
    if self.swing_direction > 0 then 
      angle_offset = math.min(angle_offset, joint_max_angle)
    else 
      angle_offset = math.max(angle_offset, joint_max_angle * self.swing_direction)
    end
    local joint = vector(angle_offset, arm_length / (#self.joints-1))
		table.insert(return_joints, joint)
	end
  --return self:jointsToVertices(return_joints, angle_dif)
  return return_joints, angle_dif
end

-- this method takes a table of joints representing the shape of the arm, uses the provided table to update the class variable self.joints, then converts self.joints into vertices and updates the arm's mesh with those vertices.
-- @param {table of vectors} joints A table holding vectors in polar format, each representing a segment in the arm. The table can hold up to the same number of joints as self.joints. If too many joints are supplied, an error is thrown.
-- @param {number} speed A number between 0 and 1, passed to the jointsToVertices() function.
-- @param {table of numbers} segment_depths A table holding the depths of each joint. passed to the jointsToVertices().
function Hand:updateArmVertices(new_joints, speed, segment_depths, joint_colors)
  if #new_joints > #self.joints then error('Too many joints supplied to function updateArmVertices()') end
  for i=1, #new_joints do
    -- we check that the value of the joint isn't nil before copying it over so that we could skip joints if we wanted
    if new_joints[i] then self.joints[i] = new_joints[i] end
  end
  speed = speed or 0
  local vertices = self:jointsToVertices(self.joints, speed, segment_depths, joint_colors)
  self.mesh:setVertices(vertices)
  self.end_arm_pos = self:jointsToPlayerCoordinates(self.joints)[#self.joints]
end
  

-- This method takes a list of joints representing the shape of the arm and returns a list of vertices that can be added to a mesh drawn with drawMode "strip"
-- @param {table of vectors} joints A table holding vectors in polar format, each representing a segment in the arm.
-- @param {number} speed A number between 0 and 1, used to decide how large the smear effect will be (not used right not)
-- @param {table of numbers} segment_depths A table holding the depths of each joint. If the table isn't supplied, then the depth of the segment is set to a default.
-- @param {table of numbers} joint_colors A table holding 4 numbers representing the color of that joint
function Hand:jointsToVertices(joints, speed, segment_depths, joint_colors)
  local MAX_WIDTH = 2 --the width the arm at the end of the arm
  local vertices = {}
  table.insert(vertices, {self.arm_origin.x, self.arm_origin.y, 0, 0, 0, 1, 0.5, 1, 0})
  local last_path = self.arm_origin
  local last_angle = 0
  -- intializes the maximum smear length value based on the speed parameter
  local MAX_SMEAR_LENGTH = math.min(speed, 1) * 2
  
  for i=1, #joints do
    -- here, we make it so the current joint is positioned relative to the last joint. To do this, we add the last_angle variable to the relative angle of the current joint. last_angle is the angle that the current joint is being placed relative to, which means that last_angle is in world space: it's relative to the world origin.
    local relative_joint_pos = vector(last_angle + joints[i].x, joints[i].y)
    relative_joint_pos = vector.fromPolar(relative_joint_pos:unpack())
    --local vertex_offset = relative_joint_pos:perpendicular():normalizeInplace()
    --vertex_offset = vertex_offset * math.min((i / #joints) * MAX_WIDTH + 1, MAX_WIDTH + 1)
    
    -- sets the last_angle variable to the angle of the current joint, so that the next joint can be relative to this one.
    last_angle = last_angle + joints[i].x
    
    local arm_thickness = math.min((i / #joints) * MAX_WIDTH + 1.5, MAX_WIDTH + 1.5)
    -- offset_angle is just an angle perpindicular to the current angle of the joint. If there is no bend in the arm, this will be the angle of the position vector that decides the position of the vertex. 
    local offset_angle = (last_angle - math.pi / 2)
    -- arm_bend_angle is the angle of the next joint in the series (if the current joint isn't the last one). it's used to rotate the angle of the vertex positions so that arm segments connect more naturally at bends.
    local arm_bend_angle = ((i == #joints) and 0 or joints[i+1].x)
    
    -- if a joint's angle is above 180 degrees, these lines will convert it to an equivalent angle within the range of 180 to -180 degrees. If an angle above 180 degrees is used, it could cause the order of the vertices to be wrong, and the joint to look twisted when rendered
    arm_bend_angle = arm_bend_angle % (2*math.pi)
    if arm_bend_angle > math.pi then 
      arm_bend_angle = arm_bend_angle - (2*math.pi)
    end
    arm_bend_angle = arm_bend_angle / 2
    -- offset_length is the length of the position vector that determines the position of the inner vertex for this joint. The way it is calculated is with simple trigonometry: the normal length of the position vector (when there is no bend in the arm) divided by the cosine of the angle of the bend in the arm. the math.max is just to clamp the value down so it's no larger then the length of the arm segment itself. otherwise, when the arm bend angle is 180 degrees, the offset_length will be a huge number, due to how the math figures out.
    local offset_length = math.min(arm_thickness / math.cos(arm_bend_angle), joints[i].y)
    
    -- this variable would be used for the length of the outer vertex position, so that the outer vertex's distance from the joint would be smaller as the arm bend is steeper. However, I tried it out and the effect wasn't very good, so I'm just leaving it here. 
    --local other_length = math.max((arm_thickness * 2) - offset_length, 0)
    
    -- each joint has a positive and negative vertex, the position of which relative to the joint are determined by these vectors, positive_vertex_pos and negative_vertex_pos. It used to be that there was only one vector that determined the position of the vertices, but this meant that each vertex had to be the same distance from the joint. Now, each vertex can have their own distance from the joint.
    local positive_vertex_pos, negative_vertex_pos
    -- this if makes it so the vertex on the inside of the arm bend becomes gets farther away from the joint as the bend becomes more steep. Meanwhile, the vertex on the outside of the arm bend doesn't change. (see diagram for visual)
    if arm_bend_angle > 0 then
      positive_vertex_pos = vector.fromPolar(offset_angle + arm_bend_angle, arm_thickness)
      negative_vertex_pos = vector.fromPolar(offset_angle + arm_bend_angle, offset_length)
    else 
      positive_vertex_pos = vector.fromPolar(offset_angle + arm_bend_angle, offset_length)
      negative_vertex_pos = vector.fromPolar(offset_angle + arm_bend_angle, arm_thickness)
    end
    
    local vertex_offset = vector.fromPolar(offset_angle + arm_bend_angle, offset_length)
    
    local MAX_SMEAR_LENGTH = 9
    local CURVE_FACTOR = 6
    local smear_length = math.pow((i / #joints), CURVE_FACTOR) * MAX_SMEAR_LENGTH
    smear_length = (speed * smear_length) + 1 

    local new_vertex = vector(0,0)
    new_vertex = last_path + (relative_joint_pos + positive_vertex_pos)
    
    local depth = 0
    if segment_depths and segment_depths[i] then
      depth = segment_depths[i]
      --print(depth)
      --if i==11 then print('------') end
    else
      -- if the depth of this joint isn't supplied as a paramter, then the dot product of the new vertex and a vector pointing straight down is used to determine whether this arm segment is drawn above or below the player
      depth = vector(0, 1) * new_vertex > 0 and 1 or 0
    end
    
    -- this sets the depth value of the first vertex (the one at 0,0) to always be the same as the depth value of the first joint (the second and third vertices)
    if i==1 then vertices[1][9] = depth end
    
    local r = 0
    local g = 1
    local b = 0.5
    local a = 1
    if joint_colors and joint_colors[i] then
      r = joint_colors[i][1] or 0
      g = joint_colors[i][2] or 1
      b = joint_colors[i][3] or 0.5
      a = joint_colors[i][4] or 1
    end
    
    table.insert(vertices, {new_vertex.x, new_vertex.y, 0, 0, r, g, b, a, depth})
    --new_vertex = last_path + (relative_joint_pos - (negative_vertex_pos * smear_length))
    new_vertex = last_path + (relative_joint_pos - negative_vertex_pos)
    table.insert(vertices, {new_vertex.x, new_vertex.y, 0, 0, r, g, b, a, depth})
    
    last_path = last_path + relative_joint_pos
  end 
  
  return vertices
end

-- this function converts a list of joints (vectors in polar coordinates) to a list of vectors in normal format relative to the player's position (its basically all the functionality of jointsToVertices() except everything to do with vertices)
function Hand:jointsToPlayerCoordinates(joints)
  local return_joints = {}
  local last_path = self.arm_origin
  local last_angle = 0
  
  for i=1, #joints do
    -- here, we make it so the current joint is positioned relative to the last joint. To do this, we add the last_angle variable to the relative angle of the current joint. last_angle is the angle that the current joint is being placed relative to, which means that last_angle is in world space: it's relative to the world origin.
    local relative_joint_pos = vector(last_angle + joints[i].x, joints[i].y)
    relative_joint_pos = vector.fromPolar(relative_joint_pos:unpack())
    
    -- sets the last_angle variable to the angle of the current joint, so that the next joint can be relative to this one.
    last_angle = last_angle + joints[i].x
    table.insert(return_joints, last_path + relative_joint_pos)
    last_path = last_path + relative_joint_pos
  end
  
  return return_joints
end

function Hand:getArmEndPosition()
  return self.end_arm_pos
end
    
-- this draw function is called twice per-frame; once before the player is drawn, and once after. This is so different segments of the arm can be drawn above or below the player's sprite to create the illusion of depth.
-- the order parameter is used by the shader to know if the hand is being drawn in front or behind the player. Depending on this number (either -1 or 1), different segments of the arm will be drawn on that call. For example, a draw call with the order -1 will *only* draw arm segments that show up behind the player, leaving all over segments of the arm blank, so that the other draw call can fill them in.
function Hand:draw(x, y, order)
  love.graphics.setShader(shader)
  shader:send('draw_order', order)
  
  --if order > 0 then
    if self.showing_afterimages then
      for i,v in ipairs(self.afterimages) do
        love.graphics.draw(v, x, y, 0, 1, 1)
      end
    end
  --end

  love.graphics.draw(self.mesh, x, y, 0, 1, 1)
  --[[for i,v in ipairs(self.test_afterimages) do
    love.graphics.draw(v, x, y, 0, 1, 1)
  end]]
  love.graphics.setShader()
  local end_circle = vector(x,y) + self.end_arm_pos
  love.graphics.circle('line', end_circle.x, end_circle.y, 5)

  --love.graphics.line(x, y, x, y+100)
  --local target = (vector(-1,1):normalizeInplace() * 50) + vector(0,self.state_manager.base_height)
  love.graphics.setColor(1, 0, 0, 1)
  local target = (self.test_hold_pos:normalized() * 50)
  --love.graphics.line(x, y, x+target.x, y+target.y)
  love.graphics.setColor(1, 1, 1, 1)
  local arc1 = self.test_hold_seg
  --love.graphics.line(x, y, x+arc1.x, y+arc1.y)
  --love.graphics.line(x+arc1.x, y+arc1.y, x+target.x, y+target.y)
end

return Hand