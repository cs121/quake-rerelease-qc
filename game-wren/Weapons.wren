// Weapons.wren
// Port of the weapon management routines from weapons.qc. Critical gameplay
// behavior is implemented here, while the more involved projectile and trace
// logic is stubbed for future work.

import "./Engine" for Engine
import "./Globals" for Items, Channels, Attenuations, PlayerExtraFlags

var _WEAPON_SOUNDS = [
  "weapons/r_exp3.wav",
  "weapons/rocket1i.wav",
  "weapons/sgun1.wav",
  "weapons/guncock.wav",
  "weapons/ric1.wav",
  "weapons/ric2.wav",
  "weapons/ric3.wav",
  "weapons/spike2.wav",
  "weapons/tink1.wav",
  "weapons/grenade.wav",
  "weapons/bounce.wav",
  "weapons/shotgn2.wav"
]

var _AMMO_BITS = null
var _STUB_WARNED = {}

class WeaponsModule {
  static precache(globals) {
    for (path in _WEAPON_SOUNDS) {
      Engine.precacheSound(path)
    }
  }

  static _ammoMask() {
    if (_AMMO_BITS == null) {
      _AMMO_BITS = Engine.bitOrMany([Items.SHELLS, Items.NAILS, Items.ROCKETS, Items.CELLS])
    }
    return _AMMO_BITS
  }

  static _stubWarn(name) {
    if (_STUB_WARNED.containsKey(name)) return
    _STUB_WARNED[name] = true
    Engine.log("WeaponsModule.%s is not yet fully implemented." % name)
  }

  static _callPlayerAnimation(globals, player, animation) {
    if (animation == null || animation == "") return

    var previousSelf = globals.self
    var previousOther = globals.other
    globals.self = player
    Engine.callEntityFunction(player, animation, [])
    globals.self = previousSelf
    globals.other = previousOther
  }

  static _clearAmmoBits(player) {
    var items = player.get("items", 0)
    items = items - Engine.bitAnd(items, WeaponsModule._ammoMask())
    player.set("items", items)
    return items
  }

  static setCurrentAmmo(globals, player) {
    player.set("weaponframe", 0)
    var items = WeaponsModule._clearAmmoBits(player)
    var weapon = player.get("weapon", Items.AXE)

    if (weapon == Items.AXE) {
      player.set("currentammo", 0)
      player.set("weaponmodel", "progs/v_axe.mdl")
    } else if (weapon == Items.SHOTGUN) {
      player.set("currentammo", player.get("ammo_shells", 0))
      player.set("weaponmodel", "progs/v_shot.mdl")
      items = Engine.bitOr(items, Items.SHELLS)
    } else if (weapon == Items.SUPER_SHOTGUN) {
      player.set("currentammo", player.get("ammo_shells", 0))
      player.set("weaponmodel", "progs/v_shot2.mdl")
      items = Engine.bitOr(items, Items.SHELLS)
    } else if (weapon == Items.NAILGUN) {
      player.set("currentammo", player.get("ammo_nails", 0))
      player.set("weaponmodel", "progs/v_nail.mdl")
      items = Engine.bitOr(items, Items.NAILS)
    } else if (weapon == Items.SUPER_NAILGUN) {
      player.set("currentammo", player.get("ammo_nails", 0))
      player.set("weaponmodel", "progs/v_nail2.mdl")
      items = Engine.bitOr(items, Items.NAILS)
    } else if (weapon == Items.GRENADE_LAUNCHER) {
      player.set("currentammo", player.get("ammo_rockets", 0))
      player.set("weaponmodel", "progs/v_rock.mdl")
      items = Engine.bitOr(items, Items.ROCKETS)
    } else if (weapon == Items.ROCKET_LAUNCHER) {
      player.set("currentammo", player.get("ammo_rockets", 0))
      player.set("weaponmodel", "progs/v_rock2.mdl")
      items = Engine.bitOr(items, Items.ROCKETS)
    } else if (weapon == Items.LIGHTNING) {
      player.set("currentammo", player.get("ammo_cells", 0))
      player.set("weaponmodel", "progs/v_light.mdl")
      items = Engine.bitOr(items, Items.CELLS)
    } else {
      player.set("currentammo", 0)
      player.set("weaponmodel", "")
    }

    player.set("items", items)
  }

  static bestWeapon(globals, player) {
    var items = player.get("items", 0)

    if (player.get("waterlevel", 0) <= 1 && player.get("ammo_cells", 0) >= 1 && Engine.bitAnd(items, Items.LIGHTNING) != 0) {
      return Items.LIGHTNING
    }
    if (player.get("ammo_nails", 0) >= 2 && Engine.bitAnd(items, Items.SUPER_NAILGUN) != 0) {
      return Items.SUPER_NAILGUN
    }
    if (player.get("ammo_shells", 0) >= 2 && Engine.bitAnd(items, Items.SUPER_SHOTGUN) != 0) {
      return Items.SUPER_SHOTGUN
    }
    if (player.get("ammo_nails", 0) >= 1 && Engine.bitAnd(items, Items.NAILGUN) != 0) {
      return Items.NAILGUN
    }
    if (player.get("ammo_shells", 0) >= 1 && Engine.bitAnd(items, Items.SHOTGUN) != 0) {
      return Items.SHOTGUN
    }

    return Items.AXE
  }

  static wantsToChangeWeapon(globals, player, oldWeapon, newWeapon) {
    var extraFlags = player.get("player_flags_ex", 0)
    if (Engine.bitAnd(extraFlags, PlayerExtraFlags.CHANGE_NEVER) != 0) {
      return false
    }
    if (Engine.bitAnd(extraFlags, PlayerExtraFlags.CHANGE_ONLY_NEW) != 0 && oldWeapon == newWeapon) {
      return false
    }
    return true
  }

  static hasNoAmmo(globals, player) {
    if (player.get("currentammo", 0) != 0) return false
    if (player.get("weapon", Items.AXE) == Items.AXE) return false

    var best = WeaponsModule.bestWeapon(globals, player)
    player.set("weapon", best)
    WeaponsModule.setCurrentAmmo(globals, player)
    return true
  }

  static attack(globals, player) {
    if (WeaponsModule.hasNoAmmo(globals, player)) return

    Engine.makeVectors(player.get("v_angle", [0, 0, 0]))
    player.set("show_hostile", Engine.time() + 1)

    var weapon = player.get("weapon", Items.AXE)
    if (weapon != Items.AXE) {
      player.set("fired_weapon", 1)
    }

    if (weapon == Items.AXE) {
      Engine.playSound(player, Channels.WEAPON, "weapons/ax1.wav", 1, Attenuations.NORMAL)
      var r = Engine.random()
      if (r < 0.25) {
        WeaponsModule._callPlayerAnimation(globals, player, "player_axe1")
      } else if (r < 0.5) {
        WeaponsModule._callPlayerAnimation(globals, player, "player_axeb1")
      } else if (r < 0.75) {
        WeaponsModule._callPlayerAnimation(globals, player, "player_axec1")
      } else {
        WeaponsModule._callPlayerAnimation(globals, player, "player_axed1")
      }
      WeaponsModule.startAxeAttack(globals, player)
      player.set("attack_finished", Engine.time() + 0.5)
      return
    }

    if (weapon == Items.SHOTGUN) {
      WeaponsModule._callPlayerAnimation(globals, player, "player_shot1")
      WeaponsModule.fireShotgun(globals, player)
      player.set("attack_finished", Engine.time() + 0.5)
      return
    }

    if (weapon == Items.SUPER_SHOTGUN) {
      WeaponsModule._callPlayerAnimation(globals, player, "player_shot1")
      WeaponsModule.fireSuperShotgun(globals, player)
      player.set("attack_finished", Engine.time() + 0.7)
      return
    }

    if (weapon == Items.NAILGUN) {
      WeaponsModule._callPlayerAnimation(globals, player, "player_nail1")
      WeaponsModule.startNailgunAttack(globals, player)
      return
    }

    if (weapon == Items.SUPER_NAILGUN) {
      WeaponsModule._callPlayerAnimation(globals, player, "player_nail1")
      WeaponsModule.startSuperNailgunAttack(globals, player)
      return
    }

    if (weapon == Items.GRENADE_LAUNCHER) {
      WeaponsModule._callPlayerAnimation(globals, player, "player_rocket1")
      WeaponsModule.fireGrenade(globals, player)
      player.set("attack_finished", Engine.time() + 0.6)
      return
    }

    if (weapon == Items.ROCKET_LAUNCHER) {
      WeaponsModule._callPlayerAnimation(globals, player, "player_rocket1")
      WeaponsModule.fireRocket(globals, player)
      player.set("attack_finished", Engine.time() + 0.8)
      return
    }

    if (weapon == Items.LIGHTNING) {
      WeaponsModule._callPlayerAnimation(globals, player, "player_light1")
      WeaponsModule.startLightningAttack(globals, player)
      player.set("attack_finished", Engine.time() + 0.1)
      Engine.playSound(player, Channels.AUTO, "weapons/lstart.wav", 1, Attenuations.NORMAL)
      return
    }
  }

  static changeWeapon(globals, player) {
    var impulse = player.get("impulse", 0)
    var desired = player.get("weapon", Items.AXE)
    var ammoShortage = false

    if (impulse == 1) {
      desired = Items.AXE
    } else if (impulse == 2) {
      desired = Items.SHOTGUN
      ammoShortage = player.get("ammo_shells", 0) < 1
    } else if (impulse == 3) {
      desired = Items.SUPER_SHOTGUN
      ammoShortage = player.get("ammo_shells", 0) < 2
    } else if (impulse == 4) {
      desired = Items.NAILGUN
      ammoShortage = player.get("ammo_nails", 0) < 1
    } else if (impulse == 5) {
      desired = Items.SUPER_NAILGUN
      ammoShortage = player.get("ammo_nails", 0) < 2
    } else if (impulse == 6) {
      desired = Items.GRENADE_LAUNCHER
      ammoShortage = player.get("ammo_rockets", 0) < 1
    } else if (impulse == 7) {
      desired = Items.ROCKET_LAUNCHER
      ammoShortage = player.get("ammo_rockets", 0) < 1
    } else if (impulse == 8) {
      desired = Items.LIGHTNING
      ammoShortage = player.get("ammo_cells", 0) < 1
    }

    player.set("impulse", 0)

    var items = player.get("items", 0)
    if (Engine.bitAnd(items, desired) == 0) {
      Engine.playerPrint(player, "$qc_no_weapon", [])
      return
    }

    if (ammoShortage) {
      Engine.playerPrint(player, "$qc_not_enough_ammo", [])
      return
    }

    player.set("weapon", desired)
    WeaponsModule.setCurrentAmmo(globals, player)
  }

  static cheatCommand(globals, player) {
    if ((globals.deathmatch > 0 || globals.coop > 0) && globals.cheatsAllowed == 0) {
      return
    }

    player.set("ammo_rockets", 100)
    player.set("ammo_nails", 200)
    player.set("ammo_shells", 100)
    player.set("ammo_cells", 200)

    var items = player.get("items", 0)
    items = Engine.bitOrMany([
      items,
      Items.AXE,
      Items.SHOTGUN,
      Items.SUPER_SHOTGUN,
      Items.NAILGUN,
      Items.SUPER_NAILGUN,
      Items.GRENADE_LAUNCHER,
      Items.ROCKET_LAUNCHER,
      Items.KEY1,
      Items.KEY2,
      Items.LIGHTNING
    ])

    var armorBits = Engine.bitOrMany([Items.ARMOR1, Items.ARMOR2, Items.ARMOR3])
    items = items - Engine.bitAnd(items, armorBits)
    items = Engine.bitOr(items, Items.ARMOR3)

    player.set("items", items)
    player.set("armortype", 0.8)
    player.set("armorvalue", 200)

    player.set("weapon", Items.ROCKET_LAUNCHER)
    player.set("impulse", 0)
    WeaponsModule.setCurrentAmmo(globals, player)
  }

  static cycleWeaponCommand(globals, player) {
    player.set("impulse", 0)
    var items = player.get("items", 0)

    while (true) {
      var weapon = player.get("weapon", Items.AXE)
      var ammoShort = false

      if (weapon == Items.LIGHTNING) {
        weapon = Items.AXE
      } else if (weapon == Items.AXE) {
        weapon = Items.SHOTGUN
        ammoShort = player.get("ammo_shells", 0) < 1
      } else if (weapon == Items.SHOTGUN) {
        weapon = Items.SUPER_SHOTGUN
        ammoShort = player.get("ammo_shells", 0) < 2
      } else if (weapon == Items.SUPER_SHOTGUN) {
        weapon = Items.NAILGUN
        ammoShort = player.get("ammo_nails", 0) < 1
      } else if (weapon == Items.NAILGUN) {
        weapon = Items.SUPER_NAILGUN
        ammoShort = player.get("ammo_nails", 0) < 2
      } else if (weapon == Items.SUPER_NAILGUN) {
        weapon = Items.GRENADE_LAUNCHER
        ammoShort = player.get("ammo_rockets", 0) < 1
      } else if (weapon == Items.GRENADE_LAUNCHER) {
        weapon = Items.ROCKET_LAUNCHER
        ammoShort = player.get("ammo_rockets", 0) < 1
      } else if (weapon == Items.ROCKET_LAUNCHER) {
        weapon = Items.LIGHTNING
        ammoShort = player.get("ammo_cells", 0) < 1
      }

      player.set("weapon", weapon)

      if (Engine.bitAnd(items, weapon) != 0 && !ammoShort) {
        WeaponsModule.setCurrentAmmo(globals, player)
        return
      }
    }
  }

  static cycleWeaponReverseCommand(globals, player) {
    player.set("impulse", 0)
    var items = player.get("items", 0)

    while (true) {
      var weapon = player.get("weapon", Items.AXE)
      var ammoShort = false

      if (weapon == Items.LIGHTNING) {
        weapon = Items.ROCKET_LAUNCHER
        ammoShort = player.get("ammo_rockets", 0) < 1
      } else if (weapon == Items.ROCKET_LAUNCHER) {
        weapon = Items.GRENADE_LAUNCHER
        ammoShort = player.get("ammo_rockets", 0) < 1
      } else if (weapon == Items.GRENADE_LAUNCHER) {
        weapon = Items.SUPER_NAILGUN
        ammoShort = player.get("ammo_nails", 0) < 2
      } else if (weapon == Items.SUPER_NAILGUN) {
        weapon = Items.NAILGUN
        ammoShort = player.get("ammo_nails", 0) < 1
      } else if (weapon == Items.NAILGUN) {
        weapon = Items.SUPER_SHOTGUN
        ammoShort = player.get("ammo_shells", 0) < 2
      } else if (weapon == Items.SUPER_SHOTGUN) {
        weapon = Items.SHOTGUN
        ammoShort = player.get("ammo_shells", 0) < 1
      } else if (weapon == Items.SHOTGUN) {
        weapon = Items.AXE
      } else if (weapon == Items.AXE) {
        weapon = Items.LIGHTNING
        ammoShort = player.get("ammo_cells", 0) < 1
      }

      player.set("weapon", weapon)

      if (Engine.bitAnd(items, weapon) != 0 && !ammoShort) {
        WeaponsModule.setCurrentAmmo(globals, player)
        return
      }
    }
  }

  static serverflagsCommand(globals) {
    globals.serverFlags = globals.serverFlags * 2 + 1
  }

  static quadCheat(globals, player) {
    if (globals.cheatsAllowed == 0) return

    player.set("super_time", 1)
    player.set("super_damage_finished", Engine.time() + 30)
    var items = player.get("items", 0)
    items = Engine.bitOr(items, Items.QUAD)
    player.set("items", items)
  }

  static impulseCommands(globals, player) {
    var impulse = player.get("impulse", 0)
    if (impulse >= 1 && impulse <= 8) {
      WeaponsModule.changeWeapon(globals, player)
    } else if (impulse == 9) {
      WeaponsModule.cheatCommand(globals, player)
    } else if (impulse == 10) {
      WeaponsModule.cycleWeaponCommand(globals, player)
    } else if (impulse == 11) {
      WeaponsModule.serverflagsCommand(globals)
    } else if (impulse == 12) {
      WeaponsModule.cycleWeaponReverseCommand(globals, player)
    } else if (impulse == 255) {
      WeaponsModule.quadCheat(globals, player)
    }

    player.set("impulse", 0)
  }

  static weaponFrame(globals, player) {
    if (Engine.time() < player.get("attack_finished", 0)) {
      return
    }

    if (player.get("impulse", 0) != 0) {
      WeaponsModule.impulseCommands(globals, player)
    }

    if (player.get("button0", false)) {
      WeaponsModule.superDamageSound(globals, player)
      WeaponsModule.attack(globals, player)
    }
  }

  static superDamageSound(globals, player) {
    if (player.get("super_damage_finished", 0) > Engine.time()) {
      if (player.get("super_sound", 0) < Engine.time()) {
        player.set("super_sound", Engine.time() + 1)
        Engine.playSound(player, Channels.BODY, "items/damage3.wav", 1, Attenuations.NORMAL)
      }
    }
  }

  static startAxeAttack(globals, player) {
    WeaponsModule._stubWarn("startAxeAttack")
  }

  static fireShotgun(globals, player) {
    WeaponsModule._stubWarn("fireShotgun")
  }

  static fireSuperShotgun(globals, player) {
    WeaponsModule._stubWarn("fireSuperShotgun")
  }

  static startNailgunAttack(globals, player) {
    WeaponsModule._stubWarn("startNailgunAttack")
  }

  static startSuperNailgunAttack(globals, player) {
    WeaponsModule._stubWarn("startSuperNailgunAttack")
  }

  static fireGrenade(globals, player) {
    WeaponsModule._stubWarn("fireGrenade")
  }

  static fireRocket(globals, player) {
    WeaponsModule._stubWarn("fireRocket")
  }

  static startLightningAttack(globals, player) {
    WeaponsModule._stubWarn("startLightningAttack")
  }
}

