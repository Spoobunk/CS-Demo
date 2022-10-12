luna = require "libs.lunajson.src.lunajson"

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

return utilities
