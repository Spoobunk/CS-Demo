Object = require "libs.classic.classic"

Base_State = Object:extend()

function Base_State:enter_state()
    print("player should not be entering this state")
end

--Base_State.state_manager = require "scripts.player.player_state"
Base_State.input = {
  attack = "example",
  spin = nil,
  grab = nil,
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

Base_State.name = "base"
Base_State.canMove = false
Base_State.vulnerable = true
-- moveCamera property: three possible values
-- false : never move camera while in this state
-- 'with_input' : only move camera when the player is giving movement input
-- 'always' : move camera no matter what
Base_State.moveCamera = 'with_movement'
-- moveCameraTarget property: boolean value
-- true : the camera's target point will be updated based on the player's velocity
-- false : the camera's target point will not be updated, so it will need to be adjusted explicitly
Base_State.moveCameraTarget = true
-- moveCameraFocusMethod: two values
-- 'normal' : normal focus movement method, speeding up to focus on the player, then gradually moving in the direction of the target
-- 'fast' : method that speeds towards the target
Base_State.moveCameraFocusMethod = 'normal'

return Base_State