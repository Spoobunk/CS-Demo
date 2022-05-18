Object = require "libs.classic.classic"

Base_State = Object:extend()

function Base_State:enter_state()
    print("player should not be entering this state")
end

--Base_State.state_manager = require "scripts.player.player_state"
Base_State.input = {
    attack = "example",
    spin = nil,
    grab = nil
}

Base_State.name = "base"
Base_State.canMove = false

return Base_State