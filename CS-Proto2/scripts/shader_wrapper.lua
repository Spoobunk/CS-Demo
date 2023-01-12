-- The purpose of this script is to read shader code from multiple files and combine them into a single string that can be sent to love.graphics as valid shader code.

-- !WARNING! this script does a lot of string manipulation using Lua patterns. If the person reading this is myself coming back to this code weeks later after all of the stuff I know about patterns has fell out of my sickly little brain, then it would be useful for myself to read about Lua's string library here:
-- https://www.lua.org/pil/20.html

-- reserved variable names - these variable names are reserved, as they are used in the signature of all assmebled shader code:
-- texture_color
-- return_color
-- return_position

-- Also, you can't layer two of the same shader on top of one another, as that will lead to naming conflicts within the main function.

-- controls whether debug messages will be printed to the console. The final assembled shader code string isn't printed as result of this; if you want that, you can print out the return value of assembleShader().
local debug = false

-- patterns that find the instance of the main function of either kind of shader (only finds the first instance (why are you putting two in there???))
-- %s* specifies 0 or more spaces
-- %s+ specifies 1 or more spaces (at least one space is needed between type and name in declarations)
-- [ \n]* specifies a series of spaces and newline characters, if it is there
-- (%b{}) captures content between the brackets enclosing the function, including the brackets. You'll need to substring these out.
local main_function_patterns = {
  pixel = 
'vec4%s+effect%s*%(%s*vec4%s+color%s*,%s*Image%s+tex%s*,%s*vec2%s+texture_coords%s*,%s*vec2%s+screen_coords%s*%)[ \n]*(%b{})',
  vertex = 
  'vec4%s+position%s*%(%s*mat4%s+transform_projection%s*,%s*vec4%s+vertex_position%s*%)[ \n]*(%b{})'
}

-- here we store the signatures for the main function of the shader, as well as code that sets the intial values for the variables that will eventually be returned by the main function. This way, shaders can work with the results of the shader code that came before it. We use these when assembling the final shader code.
local main_function_signatures = {
  pixel = [[
  vec4 effect(vec4  color, Image tex, vec2 texture_coords, vec2 screen_coords )
  {
    vec4 texturecolor = Texel(tex, texture_coords);
    vec4 return_color = texturecolor * color;
]],
  vertex = [[
  vec4 position( mat4 transform_projection, vec4 vertex_position )
  {
    vec4 return_position = transform_projection * vertex_position;
]]
}

-- the return statement for each type of main_function is added after the final shader code is assembled, which means when actually writing our shaders, instead of returning anything, we just need to assign a certain variable at the end of our shader code.
-- for pixel shaders, we return the vec4 variable return_color.
-- for vertex shaders, we return the vec4 variable return_position.
local main_function_return_statements = {
  pixel = [[return return_color;
  }]],
  vertex = [[return return_position;
  }]]
}


-- this pattern finds instances of uniform declarations in the global code.
-- %s+ specifies at least 1 space, which goes in-between the uniform keyword, the data type, and the uniform name
-- %w+ specifies a series of alphanumeric characters at least 1 character long, which all valid data types in glsl should fit within.
-- %S+ specifies at least 1 character that ISN'T a space, which matches the uniform name. (i could check that the name of the uniform is a possible variable name in glsl, but that's probably not worth it, the shader compilation would throw an error anyway)
local uniform_pattern = '(uniform%s+%w+%s+%S+%s*;)'

-- this pattern captures instances of function definitions in the global code (this would capture the effect or position function, so you should only use this pattern on global code, where the main function has already been cut out)
-- note: this pattern only captures instances of function DEFINITION, so it looks over function declarations, or when you declare that a function exists but don't give it a body yet. But that's okay, because duplicate function declarations don't actually raise an error in glsl, like definitions do.
-- note2: overloading functions in glsl doesn't raise an error, but my system only checks function names for duplication, which means overloaded functions could be deleted. But to keep things simple, I'm just going to never overload functions when writing shaders.

-- %w+ specifies a series of alphanumeric characters at least 1 character long, which all valid data types in glsl should fit within.
-- %s+ specifies at least 1 space, which goes in-between the data type and function name.
-- %S+ specifies at least 1 character that ISN'T a space. this matches the function name.
-- %s* specifies 0 or more spaces, which goes in-between the function name and the function parameters (spaces are optional)
-- %b() specifies a pair of parentheses, which matches the function parameters.
-- [ \n]* specifies 0 or more space OR newline charaters, which goes in-between the function parameters and the function defintion.
-- note: I'm putting %s+ between stuff like the data type and the name of the function, although you could put a newline in that space and glsl would except it. I'm just assuming that I'm never going to put a newline between the data type and name when writing the code, because why would I do that. I'm putting [ \n]* between the parameters and function definition, because I usually start a new line before starting my brackets.
-- %b{} specifies a pair of brackets, which match the function definition.
local function_pattern = '(%w+%s+%S+%s*%b()[ \n]*%b{})'

-- table for file to return with functions attached
shader_wrapper = {}

-- This function will read one or multiple files with with incomplete shader, then assemble them into a complete shader.
-- @param {string} shaderType The type of shader to assemble, either vertex or pixel (fragment)
-- @param {string, variable arg} ... (at least 1 required) The name of the file that contains shader code you want included in the final assembled shader. A variable argument, the order in which the arguments are supplied is the order in which they are concatenated into the final shader, so the order of arguments matters.
function shader_wrapper.assembleShader(shaderType, ...)
  -- errors if there no arguments were passed to the vararg
  assert(select('#', ...) ~= 0, "no filename arguments passed to the assembleShader function")
  
  -- this would check if there was only one shader listed to be assembled, and would circumvent the process of checking for duplicate uniforms. but we still have to account for the intializtion and return of the return_color variable, which isn't included in the shader code files themselves... its a WIP.
  --[[
  if select('#', ...) == 1 and type(select('1', ...)) == 'string' then
    io.input('shaders/' .. select('1', ...) .. '.' .. shaderType .. '.sc')
  ]]
    
  -- this creates a table with all of the values from the vararg (...)
  -- this automatically rejects any nil arguments, so keep that in mind if you see the number of shaders printed doesn't match up with the number of shaders actually processed in the loop.
  local args = {...}
  if debug then print('number of shaders: ' .. select('#', ...)) end
    
  local final_global_code = ""
  local final_function_body = ""
  -- So, GLSL does NOT like it when we declare multiple uniforms or functions with the same name. But, this might very well happen, when two shaders want the same information (i.e. the size of the texture in pixels) to do their thing. So, as we assemble each shader, we save the names of the uniforms and functions they declare here. If another shader down the line declares a uniform (or function) with the same name, we'll delete that declaration from the final code so that GLSL doesn't throw a tantrum.
  -- these tables hold the names of every uniform and function defined in every shader. They're stored here so we can check and prevent duplicate uniforms or functions.
  local uniforms = {}
  local functions = {}
  
  for i,v in ipairs(args) do
    assert(type(v) == 'string', "the assembleShader function was passed a non-string argument as a file name")
    if debug then print('\nProcessing shader: ' .. v .. '\n') end
    -- opens the requested file
    io.input('shaders/' .. v .. '.' .. shaderType .. '.sc')
    -- this line reads the shader code file and removes all spaces and newline characters before saving it to a string. this makes it so I can search for specific phrases without worrying about any stray spaces or newlines messing up the search.
    --local code = string.gsub(io.read("*all"), '[ \n]', '')
    local code = io.read("*all")
    -- the main function patterns return a capture:
    -- main_function_body receives only the body of the main function, including the brackets.
    local _, _, main_function_body = string.find(code, main_function_patterns[shaderType])
    -- here we substring out the brackets that surround the body of the main function.
    main_function_body = string.sub(main_function_body, 2, -2)
    -- then we concatenate it to all of the main function code that came before it.
    final_function_body = final_function_body .. '\n' .. main_function_body
    -- we delete the entire main function from the code, leaving only global code (uniform declarations, function definitions)
    -- for some reason, string.gsub(code, main_function, '') never actually finds the main function. luckily, just using the pattern we use to get the function body works.
    code = string.gsub(code, main_function_patterns[shaderType], '')
    
    -- this goes through the global code and runs a function on every instance of a uniform declaration, as specified by the uniform_pattern. the function receives uniform_declaration, which is just the declaration of the uniform as a string.
    code = string.gsub(code, uniform_pattern, function(uniform_declaration)
        if debug then print('uniform declaration: ' .. "'" .. uniform_declaration .. "'") end
        -- this captures the name of the uniform
        _, _, uniform_name = string.find(uniform_declaration, 'uniform%s+%w+%s+(%S+)%s*;')
        if debug then print('uniform name: ' .. "'" .. uniform_name .. "'\n") end
        -- this checks the uniforms table to see if a uniform has been declared with the same name already. If so, the declaration is deleted (substituted with an empty string)
        for i = 1, #uniforms do
          if uniforms[i] == uniform_name then 
            if debug then print('duplicate uniform... removing declaration\n') end
            return ''
          end
        end
        -- if the uniform has not already been declared, it is added to the uniforms table.
        table.insert(uniforms, uniform_name)
        -- and we don't return anything, so nothing has changed.
      end)
    
    -- this does the exact same thing we just did with uniforms but with functions.
    code = string.gsub(code, function_pattern, function(function_definition)
      if debug then print('function definition: ' .. "'" .. function_definition .. "'") end
      _, _, function_name = string.find(function_definition, '%w+%s+(%S+)%s*%b()[ \n]*%b{}')
      if debug then print('function name: ' .. "'" .. function_name .. "'\n") end
      for i = 1, #functions do
        if functions[i] == function_name then 
          if debug then print('duplicate function... removing definition\n') end
          return ''
        end
      end
      table.insert(functions, function_name)
    end)
  
    -- then we concatenate the result to all of the global code that came before it.
    final_global_code = final_global_code .. '\n' .. code
  end
  if debug then print('\ndone!!\n') end
  -- after we've gone through every individual file, we assemble and return the final code:
  return final_global_code .. main_function_signatures[shaderType] .. final_function_body .. main_function_return_statements[shaderType]
end

return shader_wrapper