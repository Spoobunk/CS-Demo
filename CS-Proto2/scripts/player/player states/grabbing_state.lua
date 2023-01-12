Base_State = require "scripts.player.player states.base_state"

Grabbing_State = Base_State:extend()

function Grabbing_State.enter_state(state_manager, from_state)

end

function Grabbing_State.exit(state_manager, to_state)
  -- this exit function makes it so regardless of whether the player finishes an attack naturally, or they are interuppted by something, the attack will exit gracefully. this may cause problems for grabs, so watch out.
  state_manager.player_components.attack:exit_attack(to_state)
  state_manager:setInputBuffering('all', false)
end

Grabbing_State.input = {
  attack = nil,
  spin = nil,
  grab = nil,
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

Grabbing_State.name = "grabbing"
Grabbing_State.canMove = false
Grabbing_State.vulnerable = true
Grabbing_State.flip_sprite_horizontal = false
Grabbing_State.moveCamera = 'with_movement'
Grabbing_State.moveCameraTarget = false
Grabbing_State.moveCameraFocusMethod = 'normal'

return Grabbing_State