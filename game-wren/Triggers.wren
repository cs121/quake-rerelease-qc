// Triggers.wren
// Ports the core trigger logic from triggers.qc so that level scripts and
// mission logic function when running under the Wren gameplay layer.

import "./Engine" for Engine
import "./Globals" for SolidTypes, DamageValues, Channels, Attenuations
import "./Globals" for MessageTypes, ServiceCodes, PlayerFlags
import "./Subs" for SubsModule
import "./Combat" for CombatModule

var _SPAWNFLAG_NOMESSAGE = 1
var _SPAWNFLAG_NOTOUCH = 1
var _PLAYER_ONLY = 1
var _SILENT = 2
var _PUSH_ONCE = 1

var _TELEPORT_SOUNDS = [
  "misc/r_tele1.wav",
  "misc/r_tele2.wav",
  "misc/r_tele3.wav",
  "misc/r_tele4.wav",
  "misc/r_tele5.wav"
]

var _STUB_WARNED = {}

class TriggersModule {
  static _vectorAdd(a, b) {
    return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
  }

  static _vectorSub(a, b) {
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
  }

  static _vectorScale(v, scalar) {
    return [v[0] * scalar, v[1] * scalar, v[2] * scalar]
  }

  static _vectorDot(a, b) {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  }

  static _vectorIsZero(v) {
    return v[0] == 0 && v[1] == 0 && v[2] == 0
  }

  static _vectorMidpoint(a, b) {
    return [(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, (a[2] + b[2]) * 0.5]
  }

  static _stubWarn(name) {
    if (_STUB_WARNED.containsKey(name)) return
    _STUB_WARNED[name] = true
    Engine.log("TriggersModule.%s is not yet fully implemented." % name)
  }

  static triggerReactivate(globals, trigger) {
    if (trigger == null) return
    trigger.set("solid", SolidTypes.TRIGGER)
  }

  static multiWait(globals, trigger) {
    if (trigger == null) return
    var maxHealth = trigger.get("max_health", 0)
    if (maxHealth != 0) {
      trigger.set("health", maxHealth)
      trigger.set("takedamage", DamageValues.YES)
      trigger.set("solid", SolidTypes.BBOX)
    }
  }

  static _playTeleportSound(globals, trigger) {
    var index = (Engine.random() * _TELEPORT_SOUNDS.count).floor
    if (index < 0) index = 0
    if (index >= _TELEPORT_SOUNDS.count) index = _TELEPORT_SOUNDS.count - 1
    var sample = _TELEPORT_SOUNDS[index]
    Engine.playSound(trigger, Channels.VOICE, sample, 1, Attenuations.NORMAL)
  }

  static multiTrigger(globals, trigger) {
    if (trigger == null) return
    var nextThink = trigger.get("nextthink", 0.0)
    if (nextThink > Engine.time()) return

    var enemy = trigger.get("enemy", null)
    var classname = trigger.get("classname", "")
    if (classname == "trigger_secret") {
      if (enemy == null || enemy.get("classname", "") != "player") {
        return
      }
      globals.foundSecrets = globals.foundSecrets + 1
      Engine.writeByte(MessageTypes.ALL, ServiceCodes.FOUNDSECRET, null)
      Engine.writeByte(MessageTypes.ONE, ServiceCodes.ACHIEVEMENT, enemy)
      Engine.writeString(MessageTypes.ONE, "ACH_FIND_SECRET", enemy)
    }

    var noise = trigger.get("noise", null)
    if (noise != null && noise != "") {
      Engine.playSound(trigger, Channels.VOICE, noise, 1, Attenuations.NORMAL)
    }

    trigger.set("takedamage", DamageValues.NO)

    var previousActivator = globals.activator
    globals.activator = enemy
    SubsModule.useTargets(globals, trigger, enemy)
    globals.activator = previousActivator

    var wait = trigger.get("wait", 0.0)
    if (wait > 0) {
      trigger.set("think", "TriggersModule.multiWait")
      var fireTime = Engine.time() + wait
      trigger.set("nextthink", fireTime)
      Engine.scheduleThink(trigger, "TriggersModule.multiWait", wait)
    } else {
      trigger.set("touch", "SUB_Null")
      Engine.clearTriggerTouch(trigger)
      trigger.set("think", "SubsModule.subRemove")
      trigger.set("nextthink", Engine.time() + 0.1)
      Engine.scheduleThink(trigger, "SubsModule.subRemove", 0.1)
    }

    if (enemy != null && enemy.get("classname", "") == "player") {
      var worldModel = globals.world.get("model", "")
      if (worldModel == "maps/e2m3.bsp" && trigger.get("message", "") == "$map_dopefish") {
        Engine.writeByte(MessageTypes.ONE, ServiceCodes.ACHIEVEMENT, enemy)
        Engine.writeString(MessageTypes.ONE, "ACH_FIND_DOPEFISH", enemy)
      }
    }
  }

  static multiKilled(globals, trigger) {
    if (trigger == null) return
    trigger.set("enemy", globals.damageAttacker)
    TriggersModule.multiTrigger(globals, trigger)
  }

  static multiUse(globals, trigger, activator) {
    if (trigger == null) return
    trigger.set("enemy", activator)
    TriggersModule.multiTrigger(globals, trigger)
  }

  static multiTouch(globals, trigger, other) {
    if (trigger == null) return
    if (other == null) return
    if (other.get("classname", "") != "player") return

    var movedir = trigger.get("movedir", [0, 0, 0])
    if (!TriggersModule._vectorIsZero(movedir)) {
      var vectors = Engine.makeVectors(other.get("angles", [0, 0, 0]))
      if (vectors != null && vectors.containsKey("forward")) {
        var forward = vectors["forward"]
        if (TriggersModule._vectorDot(forward, movedir) < 0) {
          return
        }
      }
    }

    trigger.set("enemy", other)
    TriggersModule.multiTrigger(globals, trigger)
  }

  static _configureTriggerSound(trigger) {
    var sounds = trigger.get("sounds", 0)
    if (sounds == 1) {
      Engine.precacheSound("misc/secret.wav")
      trigger.set("noise", "misc/secret.wav")
    } else if (sounds == 2) {
      Engine.precacheSound("misc/talk.wav")
      trigger.set("noise", "misc/talk.wav")
    } else if (sounds == 3) {
      Engine.precacheSound("misc/trigger1.wav")
      trigger.set("noise", "misc/trigger1.wav")
    }
  }

  static triggerMultiple(globals, trigger) {
    if (trigger == null) return

    TriggersModule._configureTriggerSound(trigger)

    if (!trigger.fields.containsKey("wait")) {
      trigger.set("wait", 0.2)
    }

    trigger.set("use", "TriggersModule.multiUse")
    SubsModule.initTrigger(globals, trigger)

    var health = trigger.get("health", 0)
    var spawnflags = trigger.get("spawnflags", 0)

    if (health != 0) {
      if ((Engine.bitAnd(spawnflags, _SPAWNFLAG_NOTOUCH)) != 0) {
        Engine.objError("health and notouch don't make sense")
      }
      trigger.set("max_health", health)
      trigger.set("th_die", "TriggersModule.multiKilled")
      trigger.set("takedamage", DamageValues.YES)
      trigger.set("solid", SolidTypes.BBOX)
      Engine.setOrigin(trigger, trigger.get("origin", [0, 0, 0]))
    } else {
      if ((Engine.bitAnd(spawnflags, _SPAWNFLAG_NOTOUCH)) == 0) {
        trigger.set("touch", "TriggersModule.multiTouch")
        Engine.setTriggerTouch(trigger, "TriggersModule.multiTouch")
      }
    }
  }

  static triggerOnce(globals, trigger) {
    if (trigger == null) return
    trigger.set("wait", -1)
    TriggersModule.triggerMultiple(globals, trigger)
  }

  static triggerRelay(globals, trigger) {
    if (trigger == null) return
    trigger.set("use", "SubsModule.useTargets")
  }

  static triggerSecret(globals, trigger) {
    if (trigger == null) return
    globals.totalSecrets = globals.totalSecrets + 1
    trigger.set("wait", -1)

    if (trigger.get("message", "") == "") {
      trigger.set("message", "$qc_found_secret")
    }

    if (trigger.get("sounds", 0) == 0) {
      trigger.set("sounds", 1)
    }

    TriggersModule._configureTriggerSound(trigger)
    TriggersModule.triggerMultiple(globals, trigger)
  }

  static counterUse(globals, trigger, activator) {
    if (trigger == null) return
    var count = trigger.get("count", 0) - 1
    trigger.set("count", count)

    if (count < 0) return
    if (count != 0) {
      if (activator != null && activator.get("classname", "") == "player") {
        if ((Engine.bitAnd(trigger.get("spawnflags", 0), _SPAWNFLAG_NOMESSAGE)) == 0) {
          if (count >= 4) {
            Engine.centerPrint(activator, "$qc_more_go")
          } else if (count == 3) {
            Engine.centerPrint(activator, "$qc_three_more")
          } else if (count == 2) {
            Engine.centerPrint(activator, "$qc_two_more")
          } else {
            Engine.centerPrint(activator, "$qc_one_more")
          }
        }
      }
      return
    }

    if (activator != null && activator.get("classname", "") == "player") {
      if ((Engine.bitAnd(trigger.get("spawnflags", 0), _SPAWNFLAG_NOMESSAGE)) == 0) {
        Engine.centerPrint(activator, "$qc_sequence_completed")
      }
    }

    trigger.set("enemy", activator)
    TriggersModule.multiTrigger(globals, trigger)
  }

  static triggerCounter(globals, trigger) {
    if (trigger == null) return
    trigger.set("wait", -1)
    if (trigger.get("count", 0) == 0) {
      trigger.set("count", 2)
    }
    trigger.set("use", "TriggersModule.counterUse")
  }

  static _findTeleportTarget(globals, trigger) {
    var targetName = trigger.get("target", null)
    if (targetName == null || targetName == "") return null
    var matches = Engine.findByField(globals.world, "targetname", targetName)
    if (matches == null || matches.count == 0) return null
    return matches[0]
  }

  static teleportTouch(globals, trigger, other) {
    if (trigger == null) return
    if (other == null) return

    var targetName = trigger.get("targetname", null)
    if (targetName != null && targetName != "") {
      if (trigger.get("nextthink", 0.0) < Engine.time()) {
        return
      }
    }

    if (Engine.bitAnd(trigger.get("spawnflags", 0), _PLAYER_ONLY) != 0) {
      if (other.get("classname", "") != "player") return
    }

    if (other.get("health", 0) <= 0) return
    if (other.get("solid", SolidTypes.SLIDEBOX) != SolidTypes.SLIDEBOX) return

    SubsModule.useTargets(globals, trigger, other)

    TriggersModule._playTeleportSound(globals, trigger)
    Engine.spawnTeleportFog(other.get("origin", [0, 0, 0]))

    var target = TriggersModule._findTeleportTarget(globals, trigger)
    if (target == null) {
      Engine.objError("couldn't find target")
      return
    }

    var targetOrigin = target.get("origin", [0, 0, 0])
    var destAngles = target.get("mangle", target.get("angles", [0, 0, 0]))
    var vectors = Engine.makeVectors(destAngles)
    var forward = (vectors != null && vectors.containsKey("forward")) ? vectors["forward"] : [0, 0, 1]
    var fogOrigin = TriggersModule._vectorAdd(targetOrigin, TriggersModule._vectorScale(forward, 32))
    Engine.spawnTeleportFog(fogOrigin)
    Engine.spawnTeleportDeath(targetOrigin, other, other.get("mins", [0, 0, 0]), other.get("maxs", [0, 0, 0]))

    Engine.setOrigin(other, targetOrigin)
    other.set("origin", targetOrigin)
    other.set("angles", destAngles)

    var flags = other.get("flags", 0)
    flags = flags - Engine.bitAnd(flags, PlayerFlags.ONGROUND)
    other.set("flags", flags)

    if (other.get("classname", "") == "player") {
      other.set("fixangle", true)
      other.set("teleport_time", Engine.time() + 0.7)
      var velocity = TriggersModule._vectorScale(forward, 300)
      other.set("velocity", velocity)
    } else {
      var velocity = other.get("velocity", [0, 0, 0])
      velocity = TriggersModule._vectorScale(forward, TriggersModule._vectorDot(forward, velocity))
      other.set("velocity", velocity)
    }
  }

  static teleportUse(globals, trigger, activator) {
    if (trigger == null) return
    trigger.set("nextthink", Engine.time() + 0.2)
    globals.forceRetouch = 2
    trigger.set("think", "SubsModule.subNull")
  }

  static triggerTeleport(globals, trigger) {
    if (trigger == null) return

    SubsModule.initTrigger(globals, trigger)
    trigger.set("touch", "TriggersModule.teleportTouch")
    Engine.setTriggerTouch(trigger, "TriggersModule.teleportTouch")

    if (trigger.get("target", null) == null || trigger.get("target", "") == "") {
      Engine.objError("no target")
    }

    trigger.set("use", "TriggersModule.teleportUse")
    trigger.set("netname", "trigger_teleport")

    if (Engine.bitAnd(trigger.get("spawnflags", 0), _SILENT) == 0) {
      Engine.precacheSound("ambience/hum1.wav")
      var mins = trigger.get("mins", [0, 0, 0])
      var maxs = trigger.get("maxs", [0, 0, 0])
      var origin = TriggersModule._vectorMidpoint(mins, maxs)
      Engine.ambientSound(origin, "ambience/hum1.wav", 0.5, Attenuations.STATIC)
    }
  }

  static infoTeleportDestination(globals, info) {
    if (info == null) return
    info.set("mangle", info.get("angles", [0, 0, 0]))
    info.set("angles", [0, 0, 0])
    info.set("model", "")
    info.set("origin", TriggersModule._vectorAdd(info.get("origin", [0, 0, 0]), [0, 0, 27]))
    if (info.get("targetname", "") == "") {
      Engine.objError("no targetname")
    }
  }

  static hurtOn(globals, trigger) {
    if (trigger == null) return
    trigger.set("solid", SolidTypes.TRIGGER)
    trigger.set("nextthink", -1)
  }

  static hurtTouch(globals, trigger, other) {
    if (trigger == null) return
    if (other == null) return

    if (other.get("takedamage", DamageValues.NO) != DamageValues.NO) {
      trigger.set("solid", SolidTypes.NOT)
      CombatModule.tDamage(globals, other, trigger, trigger, trigger.get("dmg", 5))
      trigger.set("think", "TriggersModule.hurtOn")
      trigger.set("nextthink", Engine.time() + 1)
      Engine.scheduleThink(trigger, "TriggersModule.hurtOn", 1)
    }
  }

  static triggerHurt(globals, trigger) {
    if (trigger == null) return
    SubsModule.initTrigger(globals, trigger)
    trigger.set("touch", "TriggersModule.hurtTouch")
    Engine.setTriggerTouch(trigger, "TriggersModule.hurtTouch")
    if (trigger.get("dmg", 0) == 0) {
      trigger.set("dmg", 5)
    }
  }

  static triggerPushTouch(globals, trigger, other) {
    if (trigger == null) return
    if (other == null) return

    var movedir = trigger.get("movedir", [0, 0, 0])
    var speed = trigger.get("speed", 1000) * 10
    var velocity = TriggersModule._vectorScale(movedir, speed)

    if (other.get("classname", "") == "grenade") {
      other.set("velocity", velocity)
    } else if (other.get("health", 0) > 0) {
      other.set("velocity", velocity)
      if (other.get("classname", "") == "player") {
        if (other.get("fly_sound", 0.0) < Engine.time()) {
          other.set("fly_sound", Engine.time() + 1.5)
          Engine.playSound(other, Channels.AUTO, "ambience/windfly.wav", 1, Attenuations.NORMAL)
        }
      }
    }

    if (Engine.bitAnd(trigger.get("spawnflags", 0), _PUSH_ONCE) != 0) {
      Engine.removeEntity(trigger)
    }
  }

  static triggerPush(globals, trigger) {
    if (trigger == null) return
    SubsModule.initTrigger(globals, trigger)
    Engine.precacheSound("ambience/windfly.wav")
    trigger.set("touch", "TriggersModule.triggerPushTouch")
    Engine.setTriggerTouch(trigger, "TriggersModule.triggerPushTouch")
    trigger.set("netname", "trigger_push")
    if (trigger.get("speed", 0) == 0) {
      trigger.set("speed", 1000)
    }
  }

  static triggerSkillTouch(globals, trigger, toucher) {
    if (toucher == null) return
    if (toucher.get("classname", "") != "player") return
    Engine.cvarSet("skill", trigger.get("message", ""))
  }

  static triggerSetSkill(globals, trigger) {
    if (trigger == null) return
    SubsModule.initTrigger(globals, trigger)
    trigger.set("touch", "TriggersModule.triggerSkillTouch")
    Engine.setTriggerTouch(trigger, "TriggersModule.triggerSkillTouch")
  }

  static triggerOnlyRegisteredTouch(globals, trigger, toucher) {
    if (toucher == null) return
    if (toucher.get("classname", "") != "player") return

    if (trigger.get("attack_finished", 0.0) > Engine.time()) return
    trigger.set("attack_finished", Engine.time() + 2)

    if (Engine.cvar("registered") != 0) {
      trigger.set("message", "")
      SubsModule.useTargets(globals, trigger, toucher)
      Engine.removeEntity(trigger)
    } else {
      var message = trigger.get("message", "")
      if (message != "") {
        Engine.centerPrint(toucher, message)
        Engine.playSound(toucher, Channels.BODY, "misc/talk.wav", 1, Attenuations.NORMAL)
      }
    }
  }

  static triggerOnlyRegistered(globals, trigger) {
    if (trigger == null) return
    Engine.precacheSound("misc/talk.wav")
    SubsModule.initTrigger(globals, trigger)
    trigger.set("touch", "TriggersModule.triggerOnlyRegisteredTouch")
    Engine.setTriggerTouch(trigger, "TriggersModule.triggerOnlyRegisteredTouch")
  }

  static triggerMonsterJumpTouch(globals, trigger, other) {
    if (trigger == null) return
    if (other == null) return

    var flags = other.get("flags", 0)
    var mask = Engine.bitOrMany([PlayerFlags.MONSTER, PlayerFlags.FLY, PlayerFlags.SWIM])
    if (Engine.bitAnd(flags, mask) != PlayerFlags.MONSTER) return

    var velocity = other.get("velocity", [0, 0, 0])
    var movedir = trigger.get("movedir", [0, 0, 0])
    var speed = trigger.get("speed", 200)

    velocity[0] = movedir[0] * speed
    velocity[1] = movedir[1] * speed

    other.set("velocity", velocity)

    if (Engine.bitAnd(flags, PlayerFlags.ONGROUND) == 0) return

    flags = flags - Engine.bitAnd(flags, PlayerFlags.ONGROUND)
    other.set("flags", flags)

    velocity[2] = trigger.get("height", 200)
    other.set("velocity", velocity)
  }

  static triggerMonsterJump(globals, trigger) {
    if (trigger == null) return
    if (trigger.get("speed", 0) == 0) {
      trigger.set("speed", 200)
    }
    if (trigger.get("height", 0) == 0) {
      trigger.set("height", 200)
    }
    var angles = trigger.get("angles", [0, 0, 0])
    if (TriggersModule._vectorIsZero(angles)) {
      trigger.set("angles", [0, 360, 0])
    }
    SubsModule.initTrigger(globals, trigger)
    trigger.set("touch", "TriggersModule.triggerMonsterJumpTouch")
    Engine.setTriggerTouch(trigger, "TriggersModule.triggerMonsterJumpTouch")
  }

  static playTeleport(globals, trigger) {
    TriggersModule._stubWarn("playTeleport")
  }

  static spawnTFog(globals, origin) {
    if (origin == null) origin = [0, 0, 0]
    Engine.spawnTeleportFog(origin)
  }

  static spawnTDeath(globals, origin, owner) {
    TriggersModule._stubWarn("spawnTDeath")
  }
}
