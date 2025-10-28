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

  static time() {
    return _requireHost("time", [])
  }

  static _requireHost(name, args) {
    Fiber.abort("Engine.%s requires a host implementation (args: %(_))." % [name, args])
  }
}
