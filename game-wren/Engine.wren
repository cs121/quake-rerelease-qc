// Engine.wren
// Provides abstraction for engine-dependent operations required by the
// ported QuakeC gameplay code. Each static method is expected to be
// implemented by the embedding host. The default implementations abort to
// signal that a binding must be supplied before execution.

class Engine {
  static precacheFile(path) {
    _requireHost("precacheFile", [path])
  }

  static precacheFile2(path) {
    _requireHost("precacheFile2", [path])
  }

  static precacheSound(path) {
    _requireHost("precacheSound", [path])
  }

  static precacheModel(path) {
    _requireHost("precacheModel", [path])
  }

  static lightstyle(index, pattern) {
    _requireHost("lightstyle", [index, pattern])
  }

  static cvar(name) {
    return _requireHost("cvar", [name])
  }

  static cvarSet(name, value) {
    _requireHost("cvarSet", [name, value])
  }

  static random() {
    return _requireHost("random", [])
  }

  static findAll(scope, className) {
    return _requireHost("findAll", [scope, className])
  }

  static spawnEntity() {
    return _requireHost("spawnEntity", [])
  }

  static setSpawnParms(entity) {
    _requireHost("setSpawnParms", [entity])
  }

  static setModel(entity, path) {
    return _requireHost("setModel", [entity, path])
  }

  static executeChangeLevel(trigger) {
    _requireHost("executeChangeLevel", [trigger])
  }

  static changeLevel(mapName) {
    _requireHost("changeLevel", [mapName])
  }

  static writeByte(channel, value, entity) {
    if (entity == null) {
      _requireHost("writeByte", [channel, value])
    } else {
      _requireHost("writeByte", [channel, value, entity])
    }
  }

  static writeString(channel, value, entity) {
    if (entity == null) {
      _requireHost("writeString", [channel, value])
    } else {
      _requireHost("writeString", [channel, value, entity])
    }
  }

  static broadcastPrint(messageId, args) {
    _requireHost("broadcastPrint", [messageId, args])
  }

  static playSound(entity, channel, sample, volume, attenuation) {
    _requireHost("playSound", [entity, channel, sample, volume, attenuation])
  }

  static applyDamage(target, inflictor, attacker, amount) {
    _requireHost("applyDamage", [target, inflictor, attacker, amount])
  }

  static runWeaponFrame(player) {
    _requireHost("runWeaponFrame", [player])
  }

  static setCurrentAmmo(player) {
    _requireHost("setCurrentAmmo", [player])
  }

  static selectBestWeapon(player) {
    return _requireHost("selectBestWeapon", [player])
  }

  static useTargets(entity, activator) {
    _requireHost("useTargets", [entity, activator])
  }

  static initTrigger(entity) {
    _requireHost("initTrigger", [entity])
  }

  static setTriggerTouch(entity, handler) {
    _requireHost("setTriggerTouch", [entity, handler])
  }

  static clearTriggerTouch(entity) {
    _requireHost("clearTriggerTouch", [entity])
  }

  static scheduleThink(entity, handler, delay) {
    _requireHost("scheduleThink", [entity, handler, delay])
  }

  static objError(message) {
    _requireHost("objError", [message])
  }

  static localCommand(command) {
    _requireHost("localCommand", [command])
  }

  static stuffCommand(entity, command) {
    _requireHost("stuffCommand", [entity, command])
  }

  static playerPrint(entity, messageId, args) {
    _requireHost("playerPrint", [entity, messageId, args])
  }

  static bitAnd(a, b) {
    return _requireHost("bitAnd", [a, b])
  }

  static bitOr(a, b) {
    return _requireHost("bitOr", [a, b])
  }

  static bitOrMany(values) {
    var result = 0
    for (value in values) {
      result = bitOr(result, value)
    }
    return result
  }

  static log(message) {
    _requireHost("log", [message])
  }

  static setOrigin(entity, origin) {
    _requireHost("setOrigin", [entity, origin])
  }

  static setSize(entity, mins, maxs) {
    _requireHost("setSize", [entity, mins, maxs])
  }

  static findRadius(origin, radius) {
    return _requireHost("findRadius", [origin, radius])
  }

  static traceLine(start, end, ignoreMonsters, ignoreEntity) {
    return _requireHost("traceLine", [start, end, ignoreMonsters, ignoreEntity])
  }

  static makeVectors(angles) {
    return _requireHost("makeVectors", [angles])
  }

  static spawnTeleportFog(origin) {
    _requireHost("spawnTeleportFog", [origin])
  }

  static spawnTeleportDeath(origin, owner, mins, maxs) {
    _requireHost("spawnTeleportDeath", [origin, owner, mins, maxs])
  }

  static time() {
    return _requireHost("time", [])
  }

  static _requireHost(name, args) {
    Fiber.abort("Engine.%s requires a host implementation (args: %(_))." % [name, args])
  }
}
