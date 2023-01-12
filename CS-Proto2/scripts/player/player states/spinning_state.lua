Base_State = require "scripts.player.player states.base_state"

SpinningState = Base_State:extend()

function SpinningState.enter_state(state_manager, from_state)
    --print(state_manager.name)
    --state_manager.player_components.attack:
    state_manager.player_components.anim:Switch_Animation('spin')
end

function SpinningState.exit(state_manager, to_state)
  
end

SpinningState.input = {
  attack = nil,
  spin = nil,
  grab = nil,
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

SpinningState.name = "spinning"
SpinningState.canMove = true
SpinningState.vulnerable = false
SpinningState.flip_sprite_horizontal = false
SpinningState.moveCamera = 'with_movement'
SpinningState.moveCameraTarget = true
SpinningState.moveCameraFocusMethod = 'normal'

return SpinningState