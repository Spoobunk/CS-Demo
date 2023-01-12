Object = require "libs.classic.classic"
vector = require "libs.hump.vector"
Timer = require "libs.hump.timer"

utilities = require 'scripts.utilities'

Hand = Object:extend()

function Hand:new(state_manager, segments)
  self.state_manager = state_manager
  self.segments = segments or 40
	local vertices = {}
  
  -- this is the position of the first vertex in the arm relative to the player's position. All other vertices are relative to this position.
  self.arm_origin = vector(0,0)
  
  -- this table contains vectors, each representing the position of a joint in the arm. each position vector is interpreted as being relative to the previous joint in the series. The vectors are in polar coordinates, with x being the angle and y being the length of the position vector.
  -- the choice of polar coordinates was made because in most cases when dealing with the idea of an arm with several joints, this format is more convenient
  self.joints = {}
	
  -- the normal legnth of each segment that makes up the arm. Each segment can define their own length in the joints table, but this is used as the standard
  self.standard_segment_length = 8.5
  
  self.angle = math.rad(0)
	
	-- Create the vertices at the edge of the circle.
	for i=1, self.segments do
		--local angle = (i / segments) * math.pi * 2

		-- Unit-circle.
    --local distance = (i+1) * 20
    local distance = 20
    local angle = (i % 2 == 0) and math.rad(-170) or math.rad(170)
    --local angle = math.rad(130)
    
		local x = math.cos(self.angle)
		local y = math.sin(self.angle)
    local dir = vector(x, y)
    local vertex = dir * distance
    --print(angle)
    vertex = vector(angle, self.standard_segment_length)
		--table.insert(vertices, vertex)
    table.insert(self.joints, vertex)
	end
	
  -- this variable holds the table of vertices used to construct the mesh that's being used currently. We save it here so that we can create an after image with the same vertices. We save the table to a variable rather than calling getVertices() on the mesh because that method is slow, and it's advised to just keep a copy of the vertices instead (from the love2d documentation) 
  self.current_vertices = self:jointsToVertices(self.joints, 0)
	self.mesh = love.graphics.newMesh(self.current_vertices, "strip")
  -- subtracting 1 to account for the center vertex
  self.MAX_DISTANCE = (self.mesh:getVertexCount() - 1) * 20
  self.PULL_DISTANCE = 20
  self.angle = math.rad(-90)
  
  self.swinging = true
  self.swing_direction = 1
  -- this value is the angle of the first joint in the arm
  self.arm_angle = math.rad(-90)
  
  self.arm_speed = 0
  -- controls whether afterimages are drawn or not
  self.showing_afterimages = false
  -- number between 0 and 1
  self.current_swing_speed = 0
  --self.swing_timing = {'in' = 2, 'out' = 0.5
  self.angle_timer = Timer:new()
  --[[
  self.angle_timer:tween(1.5 , self, {angle = math.rad(90)}, 'linear', function()
      --self.swinging = false
      --self.angle_timer:tween(1, self, {angle = self.angle + math.rad(45)}, 'out-quad', function()
          --self.swinging = true
          --self.swing_direction = -1
          --self.angle_timer:tween(5 * 0.75, self, {angle = math.rad(-90)}, 'linear')
      --end)
    end)
  self.angle_timer:tween(2, self, {arm_angle = math.rad(90)}, 'out-quad', function()
    self.angle_timer:tween(1, self, {arm_angle = math.rad(135)}, 'out-quad', function()
       self.swing_direction = -1 
       self.angle_timer:tween(2, self, {arm_angle = math.rad(-90)}, 'out-quad')
       self.angle_timer:tween(1.5, self, {angle = math.rad(-90)}, 'linear')
    end)
  end)
  ]]
  self:testSwingMotion(1)
  --self.angle_timer:after(5, function() self.swinging = false end)
  --self.angle_timer:tween(2, self, {angle = math.rad(45)}, 'linear')

  self.num_of_afterimages = 25
  -- keeps track of the amount of time between afterimages 
  self.afterimage_timer = 0
  -- afterimage_meshes is a table that holds a static number of meshes that are used as afterimages
  self.afterimages = {}
  self.afterimage_angles = {}
  for i=1, self.num_of_afterimages do
    table.insert(self.afterimages, love.graphics.newMesh(self.current_vertices, "strip"))
    table.insert(self.afterimage_angles, 0)
  end
  -- afterimage_vertices is a table holding tables of vertices, each corresponding to an afterimage mesh that uses those vertices. the size of afterimage_vertices cannot exceed the size of afterimage_meshes.
  --self.afterimage_vertices = utilities.createStack()
end

function Hand:addAfterimage(vertices)
  -- we remove the first (oldest) mesh from the table and save it to a variable
  local mesh = table.remove(self.afterimages, 1)
  -- we update the vertices of that mesh...
  mesh:setVertices(vertices)
  -- ...then we return it to the front of the table
  table.insert(self.afterimages, mesh)
  
  for i,mesh in ipairs(self.afterimages) do
    for j = 1, mesh:getVertexCount() do
      -- The 3rd vertex attribute for a standard mesh is its color.
      local alpha = (i / self.num_of_afterimages)
      --mesh:setVertexAttribute(j, 3, 0, 1, (i * 4) % 1)
      mesh:setVertexAttribute(j, 3, 0, 1, 0.5, alpha)
    end
  end
end

function Hand:updateAfterimages(dt)
  --local afterimage_difference = (self.current_swing_speed * math.rad(5))
  --print(self.current_swing_speed)
  local current_joints = utilities.deepCopy(self.joints)
  local orig_joint_angle = current_joints[1].x
  local swing_speed = 1 - math.abs(math.sin(self.angle))
  
  for i,mesh in ipairs(self.afterimages) do
    local aftimg_range = ((self.num_of_afterimages + 1) - i)
    local angle_offset = math.min(aftimg_range * math.rad(3) * self.current_swing_speed, aftimg_range * math.rad(10))

    --local vertices = self:jointsToVertices(self:cannedSwing(self.angle - (angle_offset*self.swing_direction), dt))
    
    current_joints[1] = vector(orig_joint_angle + (-angle_offset*self.swing_direction), current_joints[1].y)
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
      vertices[j][8] = afterimage_range * 0.4 + 0.55
      --vertices[j][8] = 1

    end
    --print(unpack(vertices))
    mesh:setVertices(vertices)
  end
end

function Hand:testSwingMotion(dir)
  --[[
  self.showing_afterimages = false
  self.angle_timer:tween(0.15, self, {arm_angle = math.rad(-135*dir)}, 'linear', function()
     self.swing_direction = dir 
    self.showing_afterimages = true
     self.angle_timer:tween(0.75, self, {angle = math.rad(90*dir)}, 'linear')
     self.angle_timer:tween(1, self, {arm_angle = math.rad(90*dir)}, 'out-quad', function()
      self:testSwingMotion(-dir)
     end)
  end)
  ]]
  self.showing_afterimages = true
  self.angle_timer:tween(2, self, {angle = math.rad(90)}, 'linear', function()
    self.swing_direction = -1
    self.angle_timer:tween(2, self, {angle = math.rad(-90)}, 'linear')
  end)
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

  --if number == 1 then self.arm_angle = math.rad(-90) else self.arm_angle = math.rad(-135*self.swing_direction) end
  -- here we set the angles so that the arm appears to be partway through the swing immediatly. We do this because it makes the swing feel responsive
  --self.arm_angle = math.rad(-20*self.swing_direction)
  --self.angle = math.rad(-30*self.swing_direction)
  self.arm_angle = math.rad(starting_angle + 20*offset_direction)
  self.angle = math.rad(starting_angle + 30*-self.swing_direction)
  
  self.showing_afterimages = true
  
  --self.angle_timer:tween(0.45, self, {angle = math.rad(90*self.swing_direction)}, 'out-quad')
  --self.angle_timer:tween(0.45, self, {arm_angle = math.rad(115*self.swing_direction)}, 'out-quart', function()
    --self.showing_afterimages = false
    --self.angle_timer:tween(0.2, self, {arm_angle = math.rad(115*self.swing_direction)}, 'out-quad')
  --end)
  self.angle_timer:tween(0.4, self, {angle = math.rad(starting_angle + -90*-self.swing_direction)}, 'linear')
  self.angle_timer:tween(0.4, self, {arm_angle = math.rad(starting_angle + -115*offset_direction)}, 'out-quart')
  
  self.current_swing_speed = attack_direction
  self.angle_timer:tween(0.15, self, {current_swing_speed = 0}, 'linear')
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
  self.swing_direction = dir
  local starting_angle = attack_direction == 1 and 0 or math.rad(180) 
  local offset_direction = attack_direction + self.swing_direction == 0 and 1 or -1
  
  self.angle_timer:tween(0.08, self, {arm_angle = math.rad(starting_angle + 135*offset_direction)}, 'linear')
  --self.angle_timer:tween(0.08, self, {arm_angle = math.rad(-135*dir)}, 'linear')
end

-- when calling this function externally, we don't need to provide a second argument, since that argument is only used when the function calls itself for recursion.
function Hand:retractArm(time, segment)
  self.swinging = false
  self.showing_afterimages = false
  local current_segment = segment or #self.joints
  local retract_duration = time / #self.joints
  self.angle_timer:tween(retract_duration, self.joints[current_segment], {y = 0}, 'linear', function()
    if current_segment ~= 1 then
      self:retractArm(time * 0.5, current_segment - 1)
    end
  end)
end

function Hand:update(dt)
  self.angle_timer:update(dt)

  if self.swinging then 
    --self.angle = self.angle + (0.1 * dt) * 10
    --self.current_vertices = self:cannedSwing(self.angle, dt)
    --self.mesh:setVertices(self.current_vertices)
    self:updateArmVertices(self:cannedSwing(self.angle, dt))
    self:updateAfterimages(dt)
    self.arm_angle = self.arm_angle + self.arm_speed
  else
    --self:rotate(dt)
    --self:updateAfterimages(dt)
    self:updateArmVertices(self.joints, 0)
  end
end
 -- I wanted this function to allow the string of vertices to each move with their own velocity, but have constraints on their rotation and distance from eachother to form a
 -- semi-realistic motion. However, I couldn't find a way to constrain the rotation of the vertices, so I gave up on it
function Hand:dynamicSwing(dt)
  self.angle = self.angle + (0.1 * dt) * 10
  local vertices = {}
  -- The first vertex is at the origin (0, 0) and will be the center of the circle.
	table.insert(vertices, {0, 0})
  local x = math.cos(self.angle)
  local y = math.sin(self.angle)
  local dir = vector(x, y)
  --local vertex = dir * 20 
  table.insert(vertices, {(dir * 20):unpack()})
  for i=3, self.mesh:getVertexCount() do
    --local myx, myy = Mesh:getVertex(i)
    local my_pos = vector(self.mesh:getVertex(i))
    --local prevx, prevy = Mesh:getVertex(i - 1)
    local prev_pos = vector(unpack(vertices[i-1]))
    local distance_to_prev = my_pos - prev_pos
    if distance_to_prev:len() > self.PULL_DISTANCE then
      my_pos = prev_pos + (distance_to_prev:normalized() * self.PULL_DISTANCE)
    end
    table.insert(vertices, {my_pos:unpack()})
  end
  self.mesh:setVertices(vertices)
end

function Hand:cannedSwing(angle, dt)
  -- the list of joints to return
  local return_joints = {}
  -- The first vertex is at the origin (0, 0) and the point where the arm connects with the player
	--table.insert(vertices, vector(0, 0))
  local last_angle = angle
  local swing_angle = math.rad(0)
  --local last_angle = 0
  local MAX_ANGLE = math.rad(20) -- the maximum angle between vertices
  local VERTEX_DISTANCE = 20 -- the distance between each vertex
  local SLAP_SPEED = 3 -- controls how fast the middle of the slap motion is compared to the beginning and end of the motion
  local angle_offset = MAX_ANGLE
  -- this range is used to modify the angle offset so that by the time the angle is such that the first vertex is horizontally aligned with the player, then the angle offset will become 0 and all vertices will be horizontally aligned. 
  
  -- since math.sin already returns a normalized value, we don't have to math.min anything
  local angle_dif = math.sin(angle)
  -- here we store the sign of angle_dif to apply later
  local angle_sign = utilities.sign(angle_dif)
  -- here we invert the range of angle_dif and raise it to a power, so that the effect of the arm straightening out is non-linear.
  angle_dif = math.pow(1 - math.abs(angle_dif), SLAP_SPEED) 
  -- now we invert angle_dif again so that it has the desired effect on angle_offset.
  angle_offset = angle_offset * ((1-angle_dif) * angle_sign)

  --angle_offset = angle_offset * angle_dif
  local swing_dif = angle_sign < 1 and (1-angle_dif) * math.rad(-180) or (1-angle_dif) * math.rad(45)
  --self.joints[1] = vector(swing_angle + (angle_offset*7), VERTEX_DISTANCE)
  --self.joints[1] = vector(swing_angle + swing_dif, self.standard_segment_length)
  --return_joints[1] = vector(swing_angle, self.standard_segment_length)
  --return_joints[1] = vector(swing_angle + swing_dif, self.standard_segment_length)
  return_joints[1] = vector(self.arm_angle, self.standard_segment_length)
  
  for i=2, #self.joints do

    --local distance = (i+1) * 20
    --local distance_range = math.min(distance / self.MAX_DISTANCE)
    --local angle_offset = distance_range * (math.pi/2)

    --print(distance, self.MAX_DISTANCE)
    --if distance == self.MAX_DISTANCE then print(angle_dif) end
      -- Unit-circle.
		--[[
    local x = math.cos(last_angle - angle_offset)
		local y = math.sin(last_angle - angle_offset)
    last_angle = last_angle - angle_offset
    local dir = vector(x, y)
    local vertex = dir * VERTEX_DISTANCE
    ]]
    -- range from 1 (second joint) to 0 (last joint)
    -- makes the later joints more stiff
    --local joint_range = angle_sign < 0 and 1 - ((i-2) / (#self.joints-2)) * 0.3 or 2
    --local joint_range = 1 - ((i-2) / (#self.joints-2)) * 0.2
    local joint_range = (i-2) / (#self.joints-2)
    local joint_max_angle = MAX_ANGLE - (joint_range * math.rad(10))
    -- range from 0 (near the extents of the swing) to 0.3 (near the middle of the swing)
    --local speed_range = angle_dif * 0.2
    -- these two magic numbers are fun to play around with
    local speed_range = ((angle_dif * 3) * (joint_range * 0.5)) + 1
    --local speed_range = angle_sign < 0 and angle_dif * 0.25 or angle_dif * -0.25
    --print('joint no. ' .. i .. ': ' .. math.min(joint_range + speed_range, 1))
    --angle_offset = angle_offset * math.min(joint_range + speed_range, 1.25)
    --[[
    if self.swing_direction > 0 then 
      angle_offset = math.min(angle_offset * math.min(joint_range + speed_range, 1.25), MAX_ANGLE)
    else 
      angle_offset = math.max(angle_offset * math.min(joint_range + speed_range, 1.25), MAX_ANGLE * self.swing_direction)
    end
    ]]
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
    local joint = vector(angle_offset, self.standard_segment_length)
		table.insert(return_joints, joint)
    --self.joints[i] = vertex
	end
  
  --if self.afterimage_timer > 0.05 then 
    --self:addAfterimage(self.current_vertices)
    --self.afterimage_timer = 0
  --end
  --return self:jointsToVertices(return_joints, angle_dif)
  return return_joints, angle_dif
  --self.current_vertices = self:updateMeshVertices(vertices, angle_dif)
  --self.mesh:setVertices(self.current_vertices)
end

function Hand:rotate(dt)
  local first_joint = vector(self.angle, self.standard_segment_length)
  --self.mesh:setVertices(self:updateMeshVertices(nil, 0))
  self:updateArmVertices({first_joint}, 0)
end

function Hand:updateArmVertices(new_joints, speed)
  if #new_joints > #self.joints then error('Too many joints supplied to function updateArmVertices()') end
  for i=1, #new_joints do
    -- we check that the value of the joint isn't nil before copying it over so that we could skip joints if we wanted
    if new_joints[i] then self.joints[i] = new_joints[i] end
  end
  self.mesh:setVertices(self:jointsToVertices(self.joints, speed))
end
  

-- This method takes a list of vectors representing the path and slightly displaces the vertices before adding them to the mesh so that the mesh can be drawn with drawMode "strip"
-- @param {table of vectors} vertices A table holding vectors which represents the path of the arm.
-- @param {number} speed A number between 0 and 1, used to decide how large the smear effect will be
function Hand:jointsToVertices(joints, speed)
  local MAX_WIDTH = 2 --the width the arm at the end of the arm
  local vertices = {}
  --table.insert(vertices, {path[1]:unpack()})
  table.insert(vertices, {self.arm_origin.x, self.arm_origin.y, 0, 0, 0, 1, 0.5, 1})
  --local last_path = path[1]
  local last_path = self.arm_origin
  local last_angle = 0
  -- intializes the maximum smear length value based on the speed parameter
  local MAX_SMEAR_LENGTH = math.min(speed, 1) * 2
  --self.current_swing_speed = speed
  
  
  
  --local joints = self.joints
  for i=1, #joints do
    -- a vector that describes the position of the current joint, relative to the last joint. Because the position is relative to the last joint, we rotate the vector by the angle of the last joint.
    --local relative_joint_pos = joints[i]:rotated(last_angle) 
    -- here, we make it so the current joint is positioned relative to the last joint. To do this, we add the last_angle variable to the relative angle of the current joint. last_angle is the angle that the current joint is being placed relative to, which means that last_angle is in world space: it's relative to the world origin.
    local relative_joint_pos = vector(last_angle + joints[i].x, joints[i].y)
    relative_joint_pos = vector.fromPolar(relative_joint_pos:unpack())
    --local vertex_offset = relative_joint_pos:perpendicular():normalizeInplace()
    --vertex_offset = vertex_offset * math.min((i / #joints) * MAX_WIDTH + 1, MAX_WIDTH + 1)
    
    -- sets the last_angle variable to the angle of the current joint, so that the next joint can be relative to this one.
    last_angle = last_angle + joints[i].x
    --print(joints[i])
    --print(math.deg(last_angle))
    
    local arm_thickness = math.min((i / #joints) * MAX_WIDTH + 1, MAX_WIDTH + 1)
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
    table.insert(vertices, {new_vertex.x, new_vertex.y, 0, 0, 0, 1, 0.5, 1})
    --new_vertex = last_path + (relative_joint_pos - (negative_vertex_pos * smear_length))
    new_vertex = last_path + (relative_joint_pos - negative_vertex_pos)
    table.insert(vertices, {new_vertex.x, new_vertex.y, 0, 0, 0, 1, 0.5, 1})
    
    last_path = last_path + relative_joint_pos
  end

  return vertices
end
    
function Hand:draw(x, y)
    
  if self.showing_afterimages then
    for i,v in ipairs(self.afterimages) do
      love.graphics.draw(v, x, y, 0, 1, 1)
    end
  end
  love.graphics.draw(self.mesh, x, y, 0, 1, 1)
end

return Hand