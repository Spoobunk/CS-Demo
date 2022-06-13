Base_State = require "scripts.player.player states.base_state"

Idle_State = Base_State:extend()

function Idle_State:enter_state()
    --print("idle")
end

--Idle_State.input = Idle_State.super.input
--Idle_State.input.attack = "move", "spin"
--Idle_State.input.spin = "do spin"
--Idle_State.input.grab = "do grab"

Idle_State.input = {
  attack = {'attack', 'startMashAttack'},
  spin = {"move", "spin"},
  grab = "do grab"
}

Idle_State.name = "idle"
Idle_State.canMove = true

return Idle_State