luna = require "libs.lunajson.src.lunajson"
vector = require "libs.hump.vector"

utilities = {}

function utilities.sign(number)
  return (number > 0 and 1) or (number == 0 and 0) or -1
end

function utilities.readFromJson(path)
  local json = io.open(path, "r")
  local jsonraw = json:read("*all")
  json:close()
  return luna.decode(jsonraw)
end

function utilities.randomSign()
  local rand = math.random()
  return rand >= 0.5 and 1 or -1 
end

-- copy a table
function utilities.deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        -- the 'next' thing is just another way of doing pairs()
        for orig_key, orig_value in next, orig, nil do
            copy[utilities.deepCopy(orig_key)] = utilities.deepCopy(orig_value)
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Create a Table with stack functions
function utilities:createStack()

  -- stack table
  local t = {}
  -- entry table
  t._et = {}

  -- push a value on to the stack
  function t:push(...)
    if ... then
      local targs = {...}
      -- add values
      for _,v in ipairs(targs) do
        table.insert(self._et, v)
      end
    end
  end

  -- pop a value from the stack
  function t:pop(num)

    -- get num values from stack
    local num = num or 1

    -- return table
    local entries = {}

    -- get values into entries
    for i = 1, num do
      -- get last entry
      if #self._et ~= 0 then
        table.insert(entries, self._et[#self._et])
        -- remove last value
        table.remove(self._et)
      else
        break
      end
    end
    -- return unpacked entries
    return unpack(entries)
  end

  -- get entries
  function t:getn()
    return #self._et
  end

  -- list values
  function t:list()
    for i,v in pairs(self._et) do
      print(i, v)
    end
  end
  
  return t
end


-- code for shudder effect borrowed from jonny morril's blog: (https://jonny.morrill.me/en/blog/gamedev-how-to-implement-a-camera-shake-effect/)
-- thank you!
function utilities:shudderEffect(duration, frequency, amplitude_max)
  -- shudder object to return
  local shudder = {}
  
  function shudder:init(duration, frequency, amplitude)
    self.duration = math.floor(duration * 1000)
    self.frequency = math.floor(frequency)
    self.amplitude_max = amplitude_max
    self.sampleCount = (shudder.duration/1000) * shudder.frequency
    self.samples = {}
    for i=1, self.sampleCount do self.samples[i] = math.random() * 2 - 1 end
    self.time = 0
    self.isShuddering = true
    return self
  end
  
  function shudder:update(dt)
    self.time = self.time + (dt * 1000)
    if self.time > self.duration + 500 then self.isShuddering = false end
  end
  
  -- Retrive the current amplitude
  function shudder:amplitude()
    -- find the point we are looking for, and the two sample points on either side
    local point = self.time/1000 * self.frequency
    local prev_sample = math.floor(point) + 1
    local next_sample = prev_sample + 1
    
    -- get decay
    local decay_mod = self:decay()
    
    -- return current amplitude
    local amplitude_base = (self:noise(prev_sample) + (point - (prev_sample-1))*(self:noise(next_sample) - self:noise(prev_sample))) * decay_mod
    return amplitude_base * self.amplitude_max
  end
  
  -- Retrieve the noise at the specified sample.
  -- @param {int} s The randomized sample we are interested in.
  function shudder:noise(s)
    if s > #self.samples then return 0 end
    return self.samples[s]
  end
  
  -- Get the decay of the shake as a floating point value from 0.0 to 1.0
  function shudder:decay()
    -- linear decay
    if self.time >= self.duration then return 0 end
    return (self.duration - self.time) / self.duration
  end
  
  return shudder:init(duration, frequency, amplitude)
end

-- objects should use this to get two-dimensional shudder, or one-dimensional if they prefer
-- duration: how long it goes
-- frequency: how fast it goes
-- amplitude_max: how large the displacement can be
function utilities:newShudder(duration, frequency, amplitude_max, do_x, do_y)
  -- object to return
  shudder_axes = {}
  
  function shudder_axes:init(duration, frequency, amplitude_max, do_x, do_y)
    -- saving this to trim the displacment vector in the amplitude method
    self.amplitude_max = amplitude_max
    -- this indicates whether either axis is still shuddering or not
    self.isShuddering = true
    self.axes = {0,0}
    if do_x == nil then do_x = true end
    if do_y == nil then do_y = true end
    if do_x then 
      self.axes[1] = utilities:shudderEffect(duration, frequency, amplitude_max) 
    end
    if do_y then
      self.axes[2] = utilities:shudderEffect(duration, frequency, amplitude_max)
    end
    
    return self
  end
  
  function shudder_axes:update(dt)
    for i,axis in ipairs(self.axes) do 
      if axis ~= 0 then 
        axis:update(dt) 
        if not axis.isShuddering then self.axes[i] = 0 end
      end
    end
    if self.axes[1] == 0 and self.axes[2] == 0 then self.isShuddering = false end
  end
  
  function shudder_axes:amplitude()
    --print(self.axes[1] == 0 and 0 or self.axes[1]:amplitude())
    local displacement = vector(self.axes[1] == 0 and 0 or self.axes[1]:amplitude(), self.axes[2] == 0 and 0 or self.axes[2]:amplitude())
    displacement:trimInplace(self.amplitude_max)
    return displacement
  end
  
  return shudder_axes:init(duration, frequency, amplitude_max, do_x, do_y)
end

-- this squashes the y component of a vector, using the ellipse equation: x^2/a^2 + y^2/b^2 = 1
-- @param {vector} target The vector to be squashed
-- @param {nubmer} ratio (optional) the ratio of the y axis of the ellipse to the x axis. A number between 0 and 1. default is 0.5625
function utilities.ellipsify(target, ratio)
  -- the magic number 0.5625 is 9/16; maybe I should change this for different aspect ratios
  local new_target = target:clone()
  local y_sign = utilities.sign(new_target.y)
  local new_y = math.sqrt((new_target:len()^2 - new_target.x^2) * ((ratio or 0.5625)^2)) * y_sign
  new_target.y = new_y
  return new_target
end


return utilities
