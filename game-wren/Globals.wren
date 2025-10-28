// Globals.wren
// Contains gameplay constants and the mutable global state structure that the
// ported QuakeC code expects to interact with.

import "./Entity" for GameEntity

class Items {
  static AXE { 4096 }
  static SHOTGUN { 1 }
  static KEY1 { 131072 }
  static KEY2 { 262144 }
  static INVISIBILITY { 524288 }
  static INVULNERABILITY { 1048576 }
  static SUIT { 2097152 }
  static QUAD { 4194304 }
}

class MessageTypes {
  static BROADCAST { 0 }
  static ONE { 1 }
  static ALL { 2 }
  static INIT { 3 }
}

class ServiceCodes {
  static INTERMISSION { 30 }
  static FINALE { 31 }
  static CDTRACK { 32 }
  static SELL_SCREEN { 33 }
  static ACHIEVEMENT { 52 }
}

class DamageValues {
  static NO { 0 }
}

class SolidTypes {
  static NOT { 0 }
}

class MoveTypes {
  static NONE { 0 }
}

class GameGlobals {
  construct new() {
    self = null
    other = null
    world = GameEntity.new()
    time = 0.0
    frameTime = 0.0
    mapName = ""
    deathmatch = 0.0
    coop = 0.0
    teamplay = 0.0
    serverFlags = 0.0
    totalSecrets = 0.0
    totalMonsters = 0.0
    foundSecrets = 0.0
    killedMonsters = 0.0
    spawnParms = List.filled(16, 0.0)
    nextMap = null
    gameOver = false
    campaign = 0.0
    campaignValid = false
    frameCount = 0.0
    cheatsAllowed = 0.0
    skill = 0.0
    resetFlag = false
    msgEntity = null
    bodyQueueHead = null
    startingServerFlags = 0.0
    lastSpawn = null
    intermissionRunning = 0.0
    intermissionExitTime = 0.0
  }

  setSpawnParm(index, value) {
    spawnParms[index - 1] = value
  }

  spawnParm(index) {
    return spawnParms[index - 1]
  }
}
