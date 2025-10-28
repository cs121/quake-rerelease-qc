// Player.wren
// Player-specific helpers that mirror functionality from player.qc.

import "./Globals" for SolidTypes, MoveTypes, DeadFlags

class PlayerModule {
  static setSuicideFrame(globals, player) {
    if (player.get("model", "") != "progs/player.mdl") {
      return
    }

    player.set("frame", "deatha11")
    player.set("solid", SolidTypes.NOT)
    player.set("movetype", MoveTypes.TOSS)
    player.set("deadflag", DeadFlags.DEAD)
    player.set("nextthink", -1)
  }
}
