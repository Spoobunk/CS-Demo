Gamestate = require "libs.hump.gamestate"
state_manager = require "scripts.state_manager"

-- I tried overwriting love.run to implement a fixed timestep, but it didn't seem to do anything but cause occasional framedrops
--[[
function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0
  local fixed_dt = 1/60
  local accumulator = 0

	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

    accumulator = accumulator + dt
    while accumulator >= fixed_dt do
        if love.update then love.update(fixed_dt) end
        accumulator = accumulator - fixed_dt
    end
		-- Call update and draw
		--if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())

			if love.draw then love.draw() end

			love.graphics.present()
		end

		if love.timer then love.timer.sleep(0.001) end
	end
end
]]
function love.load()
  --love.graphics.setDefaultFilter("nearest", "nearest", 1)
  --love.graphics.setLineStyle("rough")
  Gamestate.registerEvents()
  Gamestate.switch(state_manager.game)
end

function love.update()
  if love.keyboard.isDown("escape") then 
    love.event.quit()
  end
end

function love.draw()
  
end