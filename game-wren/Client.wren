// Client.wren
// Port of the essential client management and rules logic from client.qc.

import "./Engine" for Engine
import "./Globals" for GameGlobals, Items
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
      Engine.executeChangeLevel(trigger)
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
}
