Base_State = require "scripts.player.player states.base_state"

Holding_State = Base_State:extend()

function Holding_State.enter_state(state_manager, from_state)
  
end

function Holding_State.exit(state_manager, to_state)
  state_manager:setInputBuffering('all', false)
end

Holding_State.input = {
  attack = nil,
  spin = nil,
  grab = {'grab', 'readyThrow'},
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

Holding_State.name = "holding"
Holding_State.canMove = true
Holding_State.vulnerable = true
Holding_State.flip_sprite_horizontal = false
Holding_State.moveCamera = 'with_movement'
Holding_State.moveCameraTarget = true
Holding_State.moveCameraFocusMethod = 'normal'

return Holding_State