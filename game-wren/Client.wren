// Client.wren
// Port of the essential client management and rules logic from client.qc.

import "./Engine" for Engine
import "./Globals" for GameGlobals, Items, MessageTypes, ServiceCodes, DamageValues, SolidTypes, MoveTypes
import "./Entity" for GameEntity

class ClientModule {
  static setChangeParms(globals, player) {
    if (globals.resetFlag) {
      Engine.setSpawnParms(player)
      return
    }

    var health = player.get("health", 0)
    if (health <= 0 || globals.deathmatch > 0) {
      setNewParms(globals, player)
      return
    }

    var items = player.get("items", 0)
    var removable = Engine.bitOrMany([
      Items.KEY1,
      Items.KEY2,
      Items.INVISIBILITY,
      Items.INVULNERABILITY,
      Items.SUIT,
      Items.QUAD
    ])
    items = items - Engine.bitAnd(items, removable)
    player.set("items", items)

    var maxHealth = player.get("max_health", health)
    if (health > maxHealth) {
      health = maxHealth
    }
    if (health < maxHealth / 2) {
      health = maxHealth / 2
    }
    player.set("health", health)

    globals.setSpawnParm(1, player.get("items", 0))
    globals.setSpawnParm(2, player.get("health", 0))
    globals.setSpawnParm(3, player.get("armorvalue", 0))

    var shells = player.get("ammo_shells", 0)
    if (shells < 25) shells = 25
    globals.setSpawnParm(4, shells)

    globals.setSpawnParm(5, player.get("ammo_nails", 0))
    globals.setSpawnParm(6, player.get("ammo_rockets", 0))
    globals.setSpawnParm(7, player.get("ammo_cells", 0))
    globals.setSpawnParm(8, player.get("weapon", 0))
    globals.setSpawnParm(9, player.get("armortype", 0) * 100)
  }

  static setNewParms(globals, player) {
    globals.setSpawnParm(1, Engine.bitOr(Items.SHOTGUN, Items.AXE))
    var baseHealth = (globals.skill == 3 && globals.deathmatch == 0) ? 50 : 100
    globals.setSpawnParm(2, baseHealth)
    globals.setSpawnParm(3, 0)
    globals.setSpawnParm(4, 25)
    globals.setSpawnParm(5, 0)
    globals.setSpawnParm(6, 0)
    globals.setSpawnParm(7, 0)
    globals.setSpawnParm(8, 1)
    globals.setSpawnParm(9, 0)
  }

  static decodeLevelParms(globals, player) {
    if (globals.serverFlags != 0) {
      var worldModel = globals.world.get("model", "")
      if (worldModel == "maps/start.bsp") {
        setNewParms(globals, player)
      }
    }

    player.set("items", globals.spawnParm(1))
    player.set("health", globals.spawnParm(2))
    player.set("armorvalue", globals.spawnParm(3))
    player.set("ammo_shells", globals.spawnParm(4))
    player.set("ammo_nails", globals.spawnParm(5))
    player.set("ammo_rockets", globals.spawnParm(6))
    player.set("ammo_cells", globals.spawnParm(7))
    player.set("weapon", globals.spawnParm(8))
    player.set("armortype", globals.spawnParm(9) * 0.01)
  }

  static findIntermission(globals) {
    var spots = Engine.findAll(globals.world, "info_intermission")
    if (spots != null && spots.count > 0) {
      var cyc = Engine.random() * 4
      var index = cyc.floor % spots.count
      return spots[index]
    }

    spots = Engine.findAll(globals.world, "info_player_start")
    if (spots != null && spots.count > 0) {
      return spots[0]
    }

    spots = Engine.findAll(globals.world, "testplayerstart")
    if (spots != null && spots.count > 0) {
      return spots[0]
    }

    Engine.log("FindIntermission: no spot")
    return globals.world
  }

  static nextLevel(globals) {
    if (globals.nextMap != null) return

    var currentMap = globals.mapName
    var trigger = null

    if (currentMap == "start") {
      if (Engine.cvar("registered") == 0) {
        currentMap = "e1m1"
      } else if (Engine.bitAnd(globals.serverFlags, 1) == 0) {
        currentMap = "e1m1"
        globals.serverFlags = Engine.bitOr(globals.serverFlags, 1)
      } else if (Engine.bitAnd(globals.serverFlags, 2) == 0) {
        currentMap = "e2m1"
        globals.serverFlags = Engine.bitOr(globals.serverFlags, 2)
      } else if (Engine.bitAnd(globals.serverFlags, 4) == 0) {
        currentMap = "e3m1"
        globals.serverFlags = Engine.bitOr(globals.serverFlags, 4)
      } else if (Engine.bitAnd(globals.serverFlags, 8) == 0) {
        currentMap = "e4m1"
        globals.serverFlags = globals.serverFlags - 7
      }

      trigger = Engine.spawnEntity()
      trigger.set("map", currentMap)
    } else {
      var matches = Engine.findAll(globals.world, "trigger_changelevel")
      if (matches != null && matches.count > 0) {
        trigger = matches[0]
      }

      if (trigger == null || currentMap == "start") {
        trigger = Engine.spawnEntity()
        trigger.set("map", currentMap)
      }
    }

    globals.mapName = currentMap
    globals.nextMap = trigger.get("map", currentMap)
    globals.gameOver = true

    var now = Engine.time()
    var nextThink = trigger.get("nextthink", 0.0)
    if (nextThink < now) {
      trigger.set("nextthink", now + 0.1)
      executeChangeLevel(globals)
    }
  }

  static checkRules(globals, player) {
    if (globals.gameOver) return

    var timeLimit = Engine.cvar("timelimit") * 60
    var fragLimit = Engine.cvar("fraglimit")
    var now = Engine.time()

    if (timeLimit != 0 && now >= timeLimit) {
      nextLevel(globals)
      return
    }

    if (fragLimit != 0 && player.get("frags", 0) >= fragLimit) {
      nextLevel(globals)
      return
    }
  }

  static gotoNextMap(globals) {
    if (Engine.cvar("samelevel") != 0) {
      Engine.changeLevel(globals.mapName)
    } else if (globals.nextMap != null) {
      Engine.changeLevel(globals.nextMap)
    }
  }

  static exitIntermission(globals) {
    if (globals.deathmatch > 0) {
      gotoNextMap(globals)
      return
    }

    globals.intermissionExitTime = Engine.time() + 1
    globals.intermissionRunning = globals.intermissionRunning + 1

    var worldModel = globals.world.get("model", "")

    if (globals.intermissionRunning == 2) {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.CDTRACK, null)
      Engine.writeByte(MessageTypes.ALL, 2, null)
      Engine.writeByte(MessageTypes.ALL, 3, null)

      if (worldModel == "maps/e1m7.bsp") {
        if (Engine.cvar("registered") == 0) {
          Engine.writeByte(MessageTypes.ALL, ServiceCodes.FINALE, null)
          Engine.writeString(MessageTypes.ALL, "$qc_finale_e1_shareware", null)
        } else {
          Engine.writeByte(MessageTypes.ALL, ServiceCodes.FINALE, null)
          Engine.writeString(MessageTypes.ALL, "$qc_finale_e1", null)
        }
        return
      } else if (worldModel == "maps/e2m6.bsp") {
        Engine.writeByte(MessageTypes.ALL, ServiceCodes.FINALE, null)
        Engine.writeString(MessageTypes.ALL, "$qc_finale_e2", null)
        return
      } else if (worldModel == "maps/e3m6.bsp") {
        Engine.writeByte(MessageTypes.ALL, ServiceCodes.FINALE, null)
        Engine.writeString(MessageTypes.ALL, "$qc_finale_e3", null)
        return
      } else if (worldModel == "maps/e4m7.bsp") {
        Engine.writeByte(MessageTypes.ALL, ServiceCodes.FINALE, null)
        Engine.writeString(MessageTypes.ALL, "$qc_finale_e4", null)
        return
      }

      gotoNextMap(globals)
      return
    }

    if (globals.intermissionRunning == 3) {
      if (Engine.cvar("registered") == 0) {
        Engine.writeByte(MessageTypes.ALL, ServiceCodes.SELL_SCREEN, null)
        return
      }

      if (Engine.bitAnd(globals.serverFlags, 15) == 15) {
        Engine.writeByte(MessageTypes.ALL, ServiceCodes.FINALE, null)
        Engine.writeString(MessageTypes.ALL, "$qc_finale_all_runes", null)
        return
      }
    }

    gotoNextMap(globals)
  }

  static intermissionThink(globals, player) {
    if (Engine.time() < globals.intermissionExitTime) return

    var pressed = player.get("button0", false) ||
      player.get("button1", false) ||
      player.get("button2", false)

    if (!pressed) return

    exitIntermission(globals)
  }

  static executeChangeLevel(globals) {
    globals.intermissionRunning = 1

    var waitTime = (globals.deathmatch > 0) ? 5 : 2
    globals.intermissionExitTime = Engine.time() + waitTime

    Engine.writeByte(MessageTypes.ALL, ServiceCodes.CDTRACK, null)
    Engine.writeByte(MessageTypes.ALL, 3, null)
    Engine.writeByte(MessageTypes.ALL, 3, null)

    var pos = findIntermission(globals)
    var players = Engine.findAll(globals.world, "player")

    if (players != null) {
      for (other in players) {
        other.set("view_ofs", [0, 0, 0])

        var mangle = pos.get("mangle", [0, 0, 0])
        other.set("angles", mangle)
        other.set("v_angle", mangle)
        other.set("fixangle", true)
        other.set("nextthink", Engine.time() + 0.5)
        other.set("takedamage", DamageValues.NO)
        other.set("solid", SolidTypes.NOT)
        other.set("movetype", MoveTypes.NONE)
        other.set("modelindex", 0)
        Engine.setOrigin(other, pos.get("origin", [0, 0, 0]))

        if (globals.skill == 3) {
          var worldModel = globals.world.get("model", "")
          if (other.get("fired_weapon", 0) == 0 && worldModel == "maps/e1m1.bsp") {
            Engine.writeByte(MessageTypes.ONE, ServiceCodes.ACHIEVEMENT, other)
            Engine.writeString(MessageTypes.ONE, "ACH_PACIFIST", other)
          }
          if (other.get("took_damage", 0) == 0 && worldModel == "maps/e4m6.bsp") {
            Engine.writeByte(MessageTypes.ONE, ServiceCodes.ACHIEVEMENT, other)
            Engine.writeString(MessageTypes.ONE, "ACH_PAINLESS_MAZE", other)
          }
        }
      }
    }

    Engine.writeByte(MessageTypes.ALL, ServiceCodes.INTERMISSION, null)

    var worldModel = globals.world.get("model", "")
    if (globals.campaign != 0 && worldModel == "maps/e1m7.bsp") {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.ACHIEVEMENT, null)
      Engine.writeString(MessageTypes.ALL, "ACH_COMPLETE_E1M7", null)
    } else if (globals.campaign != 0 && worldModel == "maps/e2m6.bsp") {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.ACHIEVEMENT, null)
      Engine.writeString(MessageTypes.ALL, "ACH_COMPLETE_E2M6", null)
    } else if (globals.campaign != 0 && worldModel == "maps/e3m6.bsp") {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.ACHIEVEMENT, null)
      Engine.writeString(MessageTypes.ALL, "ACH_COMPLETE_E3M6", null)
    } else if (globals.campaign != 0 && worldModel == "maps/e4m7.bsp") {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.ACHIEVEMENT, null)
      Engine.writeString(MessageTypes.ALL, "ACH_COMPLETE_E4M7", null)
    }

    var nextMap = globals.nextMap
    if (worldModel == "maps/e1m4.bsp" && nextMap == "e1m8") {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.ACHIEVEMENT, null)
      Engine.writeString(MessageTypes.ALL, "ACH_FIND_E1M8", null)
    } else if (worldModel == "maps/e2m3.bsp" && nextMap == "e2m7") {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.ACHIEVEMENT, null)
      Engine.writeString(MessageTypes.ALL, "ACH_FIND_E2M7", null)
    } else if (worldModel == "maps/e3m4.bsp" && nextMap == "e3m7") {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.ACHIEVEMENT, null)
      Engine.writeString(MessageTypes.ALL, "ACH_FIND_E3M7", null)
    } else if (worldModel == "maps/e4m5.bsp" && nextMap == "e4m8") {
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.ACHIEVEMENT, null)
      Engine.writeString(MessageTypes.ALL, "ACH_FIND_E4M8", null)
    }
  }
}
