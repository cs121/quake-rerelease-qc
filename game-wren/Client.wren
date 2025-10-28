// Client.wren
// Port of the essential client management and rules logic from client.qc.

import "./Engine" for Engine
import "./Globals" for GameGlobals, Items, MessageTypes, ServiceCodes, DamageValues, SolidTypes, MoveTypes, Channels, Attenuations, Contents
import "./Entity" for GameEntity
import "./Player" for PlayerModule

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

  static clientConnect(globals, player) {
    var name = player.get("netname", "")
    Engine.broadcastPrint("$qc_entered", [name])

    if (globals.intermissionRunning > 0) {
      exitIntermission(globals)
    }
  }

  static clientDisconnect(globals, player) {
    if (globals.gameOver) return

    var name = player.get("netname", "")
    var frags = player.get("frags", 0).toString
    Engine.broadcastPrint("$qc_left_game", [name, frags])

    Engine.playSound(
      player,
      Channels.BODY,
      "player/tornoff2.wav",
      1,
      Attenuations.NONE
    )

    player.set("effects", 0)
    PlayerModule.setSuicideFrame(globals, player)
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

  static changeLevelTouch(globals, trigger, toucher) {
    if (toucher == null) return
    if (toucher.get("classname", "") != "player") return

    var noExit = Engine.cvar("noexit")
    if (noExit == 1 || (noExit == 2 && globals.mapName != "start")) {
      Engine.applyDamage(toucher, trigger, trigger, 50000)
      return
    }

    if (globals.coop > 0 || globals.deathmatch > 0) {
      var name = toucher.get("netname", "")
      Engine.broadcastPrint("$qc_exited", [name])
    }

    globals.nextMap = trigger.get("map", null)
    Engine.useTargets(trigger, toucher)

    var spawnFlags = trigger.get("spawnflags", 0)
    if (Engine.bitAnd(spawnFlags, 1) != 0 && globals.deathmatch == 0) {
      gotoNextMap(globals)
      return
    }

    Engine.clearTriggerTouch(trigger)
    Engine.scheduleThink(trigger, "Client.executeChangeLevel", 0.1)
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

  static triggerChangeLevel(globals, trigger) {
    var mapName = trigger.get("map", null)
    if (mapName == null || mapName == "") {
      Engine.objError("changelevel trigger doesn't have map")
      return
    }

    trigger.set("netname", "changelevel")
    trigger.set("killstring", "$qc_ks_tried_leave")

    Engine.initTrigger(trigger)
    Engine.setTriggerTouch(trigger, "Client.changeLevelTouch")
  }

  static clientObituary(globals, target, attacker) {
    var targetClass = target.get("classname", "")
    if (targetClass != "player") return

    var attackerClass = attacker.get("classname", "")
    var targetName = target.get("netname", "")
    var attackerName = attacker.get("netname", "")
    var attackerTeam = attacker.get("team", 0)
    var targetTeam = target.get("team", 0)

    var randomValue = Engine.random()

    if (attackerClass == "teledeath") {
      var owner = attacker.get("owner", null)
      var ownerName = owner == null ? "" : owner.get("netname", "")
      Engine.broadcastPrint("$qc_telefragged", [targetName, ownerName])
      if (owner != null) {
        owner.set("frags", owner.get("frags", 0) + 1)
      }
      return
    }

    if (attackerClass == "teledeath2") {
      Engine.broadcastPrint("$qc_satans_power", [targetName])
      target.set("frags", target.get("frags", 0) - 1)
      return
    }

    if (attackerClass == "player") {
      if (target == attacker) {
        attacker.set("frags", attacker.get("frags", 0) - 1)

        var targetWeapon = target.get("weapon", 0)
        if (targetWeapon == Items.LIGHTNING && target.get("waterlevel", 0) > 1) {
          var waterType = target.get("watertype", 0)
          if (waterType == Contents.SLIME) {
            Engine.broadcastPrint("$qc_discharge_slime", [targetName])
          } else if (waterType == Contents.LAVA) {
            Engine.broadcastPrint("$qc_discharge_lava", [targetName])
          } else {
            Engine.broadcastPrint("$qc_discharge_water", [targetName])
          }
          return
        }

        if (targetWeapon == Items.GRENADE_LAUNCHER) {
          Engine.broadcastPrint("$qc_suicide_pin", [targetName])
          return
        }

        if (randomValue >= 0.5) {
          Engine.broadcastPrint("$qc_suicide_bored", [targetName])
        } else {
          Engine.broadcastPrint("$qc_suicide_loaded", [targetName])
        }
        return
      }

      if (globals.teamplay == 2 && targetTeam == attackerTeam && attackerTeam != 0) {
        if (randomValue < 0.25) {
          Engine.broadcastPrint("$qc_ff_teammate", [attackerName])
        } else if (randomValue < 0.50) {
          Engine.broadcastPrint("$qc_ff_glasses", [attackerName])
        } else if (randomValue < 0.75) {
          Engine.broadcastPrint("$qc_ff_otherteam", [attackerName])
        } else {
          Engine.broadcastPrint("$qc_ff_friend", [attackerName])
        }

        attacker.set("frags", attacker.get("frags", 0) - 1)
        return
      }

      attacker.set("frags", attacker.get("frags", 0) + 1)

      var weapon = attacker.get("weapon", 0)
      if (weapon == Items.AXE) {
        Engine.broadcastPrint("$qc_death_ax", [targetName, attackerName])
        return
      }

      if (weapon == Items.SHOTGUN) {
        Engine.broadcastPrint("$qc_death_sg", [targetName, attackerName])
        return
      }

      if (weapon == Items.SUPER_SHOTGUN) {
        Engine.broadcastPrint("$qc_death_dbl", [targetName, attackerName])
        return
      }

      if (weapon == Items.NAILGUN) {
        Engine.broadcastPrint("$qc_death_nail", [targetName, attackerName])
        return
      }

      if (weapon == Items.SUPER_NAILGUN) {
        Engine.broadcastPrint("$qc_death_sng", [targetName, attackerName])
        return
      }

      if (weapon == Items.GRENADE_LAUNCHER) {
        if (target.get("health", 0) < -40) {
          Engine.broadcastPrint("$qc_death_gl1", [targetName, attackerName])
        } else {
          Engine.broadcastPrint("$qc_death_gl2", [targetName, attackerName])
        }
        return
      }

      if (weapon == Items.ROCKET_LAUNCHER) {
        var quadActive = attacker.get("super_damage_finished", 0) > 0
        if (quadActive && target.get("health", 0) < -40) {
          var quadRand = Engine.random()
          if (quadRand < 0.3) {
            Engine.broadcastPrint("$qc_death_rl_quad1", [targetName, attackerName])
          } else if (quadRand < 0.6) {
            Engine.broadcastPrint("$qc_death_rl_quad2", [targetName, attackerName])
          } else {
            Engine.broadcastPrint("$qc_death_rl1", [targetName, attackerName])
          }
          return
        }

        if (target.get("health", 0) < -40) {
          Engine.broadcastPrint("$qc_death_rl2", [targetName, attackerName])
        } else {
          Engine.broadcastPrint("$qc_death_rl3", [targetName, attackerName])
        }
        return
      }

      if (weapon == Items.LIGHTNING) {
        if (attacker.get("waterlevel", 0) > 1) {
          Engine.broadcastPrint("$qc_death_lg1", [targetName, attackerName])

          if (attacker.get("invincible_finished", 0) > 0) {
            globals.msgEntity = attacker
            Engine.writeByte(MessageTypes.ONE, ServiceCodes.ACHIEVEMENT, attacker)
            Engine.writeString(MessageTypes.ONE, "ACH_SURVIVE_DISCHARGE", attacker)
          }
        } else {
          Engine.broadcastPrint("$qc_death_lg2", [targetName, attackerName])
        }
        return
      }

      return
    }

    target.set("frags", target.get("frags", 0) - 1)
    var waterType = target.get("watertype", 0)
    if (waterType == Contents.WATER) {
      if (Engine.random() < 0.5) {
        Engine.broadcastPrint("$qc_death_drown1", [targetName])
      } else {
        Engine.broadcastPrint("$qc_death_drown2", [targetName])
      }
      return
    }

    if (waterType == Contents.SLIME) {
      if (Engine.random() < 0.5) {
        Engine.broadcastPrint("$qc_death_slime1", [targetName])
      } else {
        Engine.broadcastPrint("$qc_death_slime2", [targetName])
      }
      return
    }

    if (waterType == Contents.LAVA) {
      if (target.get("health", 0) < -15) {
        Engine.broadcastPrint("$qc_death_lava1", [targetName])
        return
      }

      if (Engine.random() < 0.5) {
        Engine.broadcastPrint("$qc_death_lava2", [targetName])
      } else {
        Engine.broadcastPrint("$qc_death_lava3", [targetName])
      }
      return
    }

    if (attacker.get("solid", SolidTypes.NOT) == SolidTypes.BSP && attacker != globals.world) {
      Engine.broadcastPrint("$qc_death_squish", [targetName])
      return
    }

    var killString = attacker.get("killstring", null)
    if (killString != null && killString != "") {
      Engine.broadcastPrint(killString, [targetName])
      return
    }

    var deathType = target.get("deathtype", "")
    if (deathType == "falling") {
      target.set("deathtype", "")
      Engine.broadcastPrint("$qc_death_fall", [targetName])
      return
    }

    Engine.broadcastPrint("$qc_death_died", [targetName])
  }
}
