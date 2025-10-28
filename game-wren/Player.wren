// Player.wren
// Player-specific helpers that mirror functionality from player.qc.

import "./Engine" for Engine
import "./Globals" for SolidTypes, MoveTypes, DeadFlags, Items, PlayerFlags
import "./Globals" for Channels, Attenuations, DamageValues, Contents
import "./Subs" for SubsModule
import "./Weapons" for WeaponsModule

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

  static playerPain(globals, player, attacker, damage) {
    if (player.get("weaponframe", 0) != 0) return
    if (player.get("invisible_finished", 0.0) > Engine.time()) return

    player.set("weaponframe", 0)
    PlayerModule._painSound(globals, player)

    if (player.get("weapon", Items.AXE) == Items.AXE) {
      player.set("frame", "axpain1")
    } else {
      player.set("frame", "pain1")
    }
  }

  static playerDie(globals, player) {
    var removeMask = Engine.bitOrMany([
      Items.INVISIBILITY,
      Items.INVULNERABILITY,
      Items.SUIT,
      Items.QUAD
    ])

    var items = player.get("items", 0)
    items = items - Engine.bitAnd(items, removeMask)
    player.set("items", items)

    player.set("invisible_finished", 0)
    player.set("invincible_finished", 0)
    player.set("super_damage_finished", 0)
    player.set("radsuit_finished", 0)
    player.set("effects", 0)
    player.set("modelindex", globals.modelIndexPlayer)

    if (globals.deathmatch > 0 || globals.coop > 0) {
      PlayerModule._dropBackpack(globals, player)
    }

    player.set("weaponmodel", "")
    player.set("view_ofs", [0, 0, -8])
    player.set("deadflag", DeadFlags.DYING)
    player.set("solid", SolidTypes.NOT)

    var flags = player.get("flags", 0)
    flags = flags - Engine.bitAnd(flags, PlayerFlags.ONGROUND)
    player.set("flags", flags)

    player.set("movetype", MoveTypes.TOSS)

    var velocity = player.get("velocity", [0, 0, 0])
    if (velocity[2] < 10) {
      velocity = [velocity[0], velocity[1], velocity[2] + Engine.random() * 300]
    }
    player.set("velocity", velocity)

    if (player.get("health", 0) < -40) {
      PlayerModule._gibPlayer(globals, player)
      return
    }

    PlayerModule._deathSound(globals, player)

    var angles = player.get("angles", [0, 0, 0])
    player.set("angles", [0, angles[1], 0])

    if (player.get("weapon", Items.AXE) == Items.AXE) {
      player.set("frame", "axdeth9")
    } else {
      var deathFrames = ["deatha11", "deathb9", "deathc15", "deathd9", "deathe9"]
      var frame = PlayerModule._randomChoice(deathFrames)
      if (frame == null) frame = "deatha11"
      player.set("frame", frame)
    }

    PlayerModule._playerDead(player)
  }

  static backpackTouch(globals, backpack, other) {
    if (other == null) return
    if (other.get("classname", "") != "player") return
    if (other.get("health", 0) <= 0) return

    Engine.playerPrint(other, "$qc_backpack_got", [])

    var backpackItems = backpack.get("items", 0)
    if (backpackItems != 0 && Engine.bitAnd(other.get("items", 0), backpackItems) == 0) {
      var netname = backpack.get("netname", null)
      if (netname != null && netname != "") {
        Engine.playerPrint(other, netname, [])
      }
    }

    var bestBefore = WeaponsModule.bestWeapon(globals, other)
    var oldWeapon = other.get("weapon", Items.AXE)

    other.set("ammo_shells", other.get("ammo_shells", 0) + backpack.get("ammo_shells", 0))
    other.set("ammo_nails", other.get("ammo_nails", 0) + backpack.get("ammo_nails", 0))
    other.set("ammo_rockets", other.get("ammo_rockets", 0) + backpack.get("ammo_rockets", 0))
    other.set("ammo_cells", other.get("ammo_cells", 0) + backpack.get("ammo_cells", 0))

    PlayerModule._boundAmmo(other)

    if (backpack.get("ammo_shells", 0) > 0) {
      Engine.playerPrint(other, "$qc_backpack_shells", [backpack.get("ammo_shells", 0).toString])
    }
    if (backpack.get("ammo_nails", 0) > 0) {
      Engine.playerPrint(other, "$qc_backpack_nails", [backpack.get("ammo_nails", 0).toString])
    }
    if (backpack.get("ammo_rockets", 0) > 0) {
      Engine.playerPrint(other, "$qc_backpack_rockets", [backpack.get("ammo_rockets", 0).toString])
    }
    if (backpack.get("ammo_cells", 0) > 0) {
      Engine.playerPrint(other, "$qc_backpack_cells", [backpack.get("ammo_cells", 0).toString])
    }

    var items = other.get("items", 0)
    if (backpackItems != 0) {
      items = Engine.bitOr(items, backpackItems)
      other.set("items", items)
    }

    Engine.playSound(other, Channels.ITEM, "weapons/lock4.wav", 1, Attenuations.NORMAL)
    Engine.stuffCommand(other, "bf\n")

    Engine.removeEntity(backpack)

    var newWeapon = backpackItems != 0 ? backpackItems : oldWeapon
    var bestAfter = WeaponsModule.bestWeapon(globals, other)
    if (WeaponsModule.wantsToChangeWeapon(globals, other, oldWeapon, newWeapon) && bestAfter != bestBefore) {
      other.set("weapon", bestAfter)
    } else {
      other.set("weapon", oldWeapon)
    }

    WeaponsModule.setCurrentAmmo(globals, other)
  }

  static deathBubbles(globals, player, count) {
    if (count <= 0) return

    var spawner = Engine.spawnEntity()
    var origin = player.get("origin", [0, 0, 0])
    Engine.setOrigin(spawner, origin)
    spawner.set("origin", origin)
    spawner.set("movetype", MoveTypes.NONE)
    spawner.set("solid", SolidTypes.NOT)
    spawner.set("think", "PlayerModule.deathBubblesSpawn")
    spawner.set("nextthink", Engine.time() + 0.1)
    Engine.scheduleThink(spawner, "PlayerModule.deathBubblesSpawn", 0.1)
    spawner.set("air_finished", 0)
    spawner.set("owner", player)
    spawner.set("bubble_count", count)
  }

  static deathBubblesSpawn(globals, spawner) {
    if (spawner == null) return

    var owner = spawner.get("owner", null)
    if (owner == null || owner.get("waterlevel", 0) != 3) {
      Engine.removeEntity(spawner)
      return
    }

    var bubble = Engine.spawnEntity()
    Engine.setModel(bubble, "progs/s_bubble.spr")
    var spawnOrigin = PlayerModule._vectorAdd(owner.get("origin", [0, 0, 0]), [0, 0, 24])
    Engine.setOrigin(bubble, spawnOrigin)
    bubble.set("origin", spawnOrigin)
    bubble.set("movetype", MoveTypes.NOCLIP)
    bubble.set("solid", SolidTypes.NOT)
    bubble.set("velocity", [0, 0, 15])
    bubble.set("classname", "bubble")
    bubble.set("frame", 0)
    Engine.setSize(bubble, [-8, -8, -8], [8, 8, 8])
    bubble.set("think", "SubsModule.subRemove")
    bubble.set("nextthink", Engine.time() + 0.5)
    Engine.scheduleThink(bubble, "SubsModule.subRemove", 0.5)

    var produced = spawner.get("air_finished", 0) + 1
    spawner.set("air_finished", produced)

    if (produced >= spawner.get("bubble_count", 0)) {
      Engine.removeEntity(spawner)
      return
    }

    spawner.set("nextthink", Engine.time() + 0.1)
    Engine.scheduleThink(spawner, "PlayerModule.deathBubblesSpawn", 0.1)
  }

  static _painSound(globals, player) {
    if (player.get("health", 0) < 0) return

    var attacker = globals.damageAttacker
    if (attacker != null) {
      var className = attacker.get("classname", "")
      if (className == "teledeath" || className == "teledeath2") {
        Engine.playSound(player, Channels.VOICE, "player/teledth1.wav", 1, Attenuations.NORMAL)
        return
      }
    }

    var watertype = player.get("watertype", 0)
    var waterlevel = player.get("waterlevel", 0)
    if (watertype == Contents.WATER && waterlevel == 3) {
      PlayerModule.deathBubbles(globals, player, 1)
      var sample = Engine.random() > 0.5 ? "player/drown1.wav" : "player/drown2.wav"
      Engine.playSound(player, Channels.VOICE, sample, 1, Attenuations.NORMAL)
      return
    }

    if (watertype == Contents.SLIME || watertype == Contents.LAVA) {
      var burn = Engine.random() > 0.5 ? "player/lburn1.wav" : "player/lburn2.wav"
      Engine.playSound(player, Channels.VOICE, burn, 1, Attenuations.NORMAL)
      return
    }

    var now = Engine.time()
    if (player.get("pain_finished", 0.0) > now) {
      player.set("axhitme", 0)
      return
    }

    player.set("pain_finished", now + 0.5)

    if (player.get("axhitme", 0) == 1) {
      player.set("axhitme", 0)
      Engine.playSound(player, Channels.VOICE, "player/axhit1.wav", 1, Attenuations.NORMAL)
      return
    }

    var samples = [
      "player/pain1.wav",
      "player/pain2.wav",
      "player/pain3.wav",
      "player/pain4.wav",
      "player/pain5.wav",
      "player/pain6.wav"
    ]
    var sample = PlayerModule._randomChoice(samples)
    if (sample != null) {
      Engine.playSound(player, Channels.VOICE, sample, 1, Attenuations.NORMAL)
    }
  }

  static _deathSound(globals, player) {
    if (player.get("waterlevel", 0) == 3) {
      PlayerModule.deathBubbles(globals, player, 20)
      Engine.playSound(player, Channels.VOICE, "player/h2odeath.wav", 1, Attenuations.NONE)
      return
    }

    var options = [
      "player/death1.wav",
      "player/death2.wav",
      "player/death3.wav",
      "player/death4.wav",
      "player/death5.wav"
    ]
    var sample = PlayerModule._randomChoice(options)
    if (sample != null) {
      Engine.playSound(player, Channels.VOICE, sample, 1, Attenuations.NONE)
    }
  }

  static _gibPlayer(globals, player) {
    PlayerModule._throwHead(globals, player, "progs/h_player.mdl", player.get("health", 0))
    PlayerModule._throwGib(globals, player, "progs/gib1.mdl", player.get("health", 0))
    PlayerModule._throwGib(globals, player, "progs/gib2.mdl", player.get("health", 0))
    PlayerModule._throwGib(globals, player, "progs/gib3.mdl", player.get("health", 0))

    player.set("deadflag", DeadFlags.DEAD)

    var attacker = globals.damageAttacker
    if (attacker != null) {
      var className = attacker.get("classname", "")
      if (className == "teledeath" || className == "teledeath2") {
        Engine.playSound(player, Channels.VOICE, "player/teledth1.wav", 1, Attenuations.NONE)
        return
      }
    }

    var sound = Engine.random() < 0.5 ? "player/gib.wav" : "player/udeath.wav"
    Engine.playSound(player, Channels.VOICE, sound, 1, Attenuations.NONE)
  }

  static _throwGib(globals, player, model, damage) {
    var gib = Engine.spawnEntity()
    var origin = player.get("origin", [0, 0, 0])
    Engine.setOrigin(gib, origin)
    gib.set("origin", origin)
    Engine.setModel(gib, model)
    Engine.setSize(gib, [0, 0, 0], [0, 0, 0])
    gib.set("velocity", PlayerModule._velocityForDamage(damage))
    gib.set("movetype", MoveTypes.BOUNCE)
    gib.set("solid", SolidTypes.NOT)
    gib.set("avelocity", [Engine.random() * 600, Engine.random() * 600, Engine.random() * 600])
    gib.set("think", "SubsModule.subRemove")
    var removeTime = Engine.time() + 10 + Engine.random() * 10
    gib.set("nextthink", removeTime)
    Engine.scheduleThink(gib, "SubsModule.subRemove", removeTime - Engine.time())
    gib.set("frame", 0)
    gib.set("flags", 0)
  }

  static _throwHead(globals, player, model, damage) {
    Engine.setModel(player, model)
    player.set("frame", 0)
    player.set("nextthink", -1)
    player.set("movetype", MoveTypes.BOUNCE)
    player.set("takedamage", DamageValues.NO)
    player.set("solid", SolidTypes.NOT)
    player.set("view_ofs", [0, 0, 8])
    Engine.setSize(player, [-16, -16, 0], [16, 16, 56])

    var velocity = PlayerModule._velocityForDamage(damage)
    player.set("velocity", velocity)

    var origin = player.get("origin", [0, 0, 0])
    origin = [origin[0], origin[1], origin[2] - 24]
    Engine.setOrigin(player, origin)
    player.set("origin", origin)

    var flags = player.get("flags", 0)
    flags = flags - Engine.bitAnd(flags, PlayerFlags.ONGROUND)
    player.set("flags", flags)

    player.set("avelocity", [0, (Engine.random() * 2 - 1) * 600, 0])
  }

  static _playerDead(player) {
    player.set("nextthink", -1)
    player.set("deadflag", DeadFlags.DEAD)
  }

  static _dropBackpack(globals, player) {
    var shells = player.get("ammo_shells", 0)
    var nails = player.get("ammo_nails", 0)
    var rockets = player.get("ammo_rockets", 0)
    var cells = player.get("ammo_cells", 0)

    if (shells + nails + rockets + cells == 0) return

    var pack = Engine.spawnEntity()
    var origin = player.get("origin", [0, 0, 0])
    var packOrigin = PlayerModule._vectorAdd(origin, [0, 0, -24])
    Engine.setOrigin(pack, packOrigin)
    pack.set("origin", packOrigin)

    var weapon = player.get("weapon", Items.AXE)
    pack.set("items", weapon)
    pack.set("classname", "item_backpack")

    var netname = null
    if (weapon == Items.AXE) {
      netname = "$qc_axe"
    } else if (weapon == Items.SHOTGUN) {
      netname = "$qc_shotgun"
    } else if (weapon == Items.SUPER_SHOTGUN) {
      netname = "$qc_double_shotgun"
    } else if (weapon == Items.NAILGUN) {
      netname = "$qc_nailgun"
    } else if (weapon == Items.SUPER_NAILGUN) {
      netname = "$qc_super_nailgun"
    } else if (weapon == Items.GRENADE_LAUNCHER) {
      netname = "$qc_grenade_launcher"
    } else if (weapon == Items.ROCKET_LAUNCHER) {
      netname = "$qc_rocket_launcher"
    } else if (weapon == Items.LIGHTNING) {
      netname = "$qc_thunderbolt"
    }

    if (netname != null) {
      pack.set("netname", netname)
    }

    pack.set("ammo_shells", shells)
    pack.set("ammo_nails", nails)
    pack.set("ammo_rockets", rockets)
    pack.set("ammo_cells", cells)

    if (pack.get("ammo_shells", 0) < 5 && (weapon == Items.SHOTGUN || weapon == Items.SUPER_SHOTGUN)) {
      pack.set("ammo_shells", 5)
    }
    if (pack.get("ammo_nails", 0) < 20 && (weapon == Items.NAILGUN || weapon == Items.SUPER_NAILGUN)) {
      pack.set("ammo_nails", 20)
    }
    if (pack.get("ammo_rockets", 0) < 5 && (weapon == Items.GRENADE_LAUNCHER || weapon == Items.ROCKET_LAUNCHER)) {
      pack.set("ammo_rockets", 5)
    }
    if (pack.get("ammo_cells", 0) < 15 && weapon == Items.LIGHTNING) {
      pack.set("ammo_cells", 15)
    }

    var velocity = [
      -100 + Engine.random() * 200,
      -100 + Engine.random() * 200,
      300
    ]
    pack.set("velocity", velocity)

    pack.set("flags", PlayerFlags.ITEM)
    pack.set("solid", SolidTypes.TRIGGER)
    pack.set("movetype", MoveTypes.TOSS)
    Engine.setModel(pack, "progs/backpack.mdl")
    Engine.setSize(pack, [-16, -16, 0], [16, 16, 56])
    pack.set("touch", "PlayerModule.backpackTouch")
    pack.set("think", "SubsModule.subRemove")

    var removeTime = 120.0
    pack.set("nextthink", Engine.time() + removeTime)
    Engine.scheduleThink(pack, "SubsModule.subRemove", removeTime)
  }

  static _boundAmmo(player) {
    if (player.get("ammo_shells", 0) > 100) player.set("ammo_shells", 100)
    if (player.get("ammo_nails", 0) > 200) player.set("ammo_nails", 200)
    if (player.get("ammo_rockets", 0) > 100) player.set("ammo_rockets", 100)
    if (player.get("ammo_cells", 0) > 100) player.set("ammo_cells", 100)
  }

  static _velocityForDamage(damage) {
    var v = [
      100 * PlayerModule._crandom(),
      100 * PlayerModule._crandom(),
      200 + 100 * Engine.random()
    ]

    if (damage > -50) {
      return PlayerModule._vectorScale(v, 0.7)
    }
    if (damage > -200) {
      return PlayerModule._vectorScale(v, 2)
    }
    return PlayerModule._vectorScale(v, 10)
  }

  static _vectorAdd(a, b) {
    return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
  }

  static _vectorScale(v, scale) {
    return [v[0] * scale, v[1] * scale, v[2] * scale]
  }

  static _crandom() {
    return Engine.random() * 2 - 1
  }

  static _randomChoice(options) {
    if (options == null || options.count == 0) return null
    var index = (Engine.random() * options.count).floor
    if (index >= options.count) index = options.count - 1
    return options[index]
  }
}
