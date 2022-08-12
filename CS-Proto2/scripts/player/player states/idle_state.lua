Base_State = require "scripts.player.player states.base_state"

Idle_State = Base_State:extend()

function Idle_State.enter_state(state_manager, from_state)
    --print("idle")
  state_manager.player_components.move:Set_Movement_Input(true)
  --state_manager:setInputBuffering('all', false)
end

function Idle_State.exit(state_manager, to_state)
  --state_manager.player_components.move.move_timer:clear()
  --state_manager.player_components.move.can_dodge_spin = true 
  --state_manager:setInputBuffering('spin', false)
end

--Idle_State.input = Idle_State.super.input
--Idle_State.input.attack = "move", "spin"
--Idle_State.input.spin = "do spin"
--Idle_State.input.grab = "do grab"

Idle_State.input = {
  attack = {'attack', 'startMashAttack'},
  spin = {"move", "dodgeSpin"},
  grab = {'attack', 'startGrab'},
  release_attack = nil, 
  release_spin = nil,
  release_grab = nil
}

Idle_State.name = "idle"
Idle_State.canMove = true
Idle_State.vulnerable = true
Idle_State.flip_sprite_horizontal = true

return Idle_State