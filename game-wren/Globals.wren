// Globals.wren
// Contains gameplay constants and the mutable global state structure that the
// ported QuakeC code expects to interact with.

import "./Entity" for GameEntity

class Items {
  static AXE { 4096 }
  static SHOTGUN { 1 }
  static SUPER_SHOTGUN { 2 }
  static NAILGUN { 4 }
  static SUPER_NAILGUN { 8 }
  static GRENADE_LAUNCHER { 16 }
  static ROCKET_LAUNCHER { 32 }
  static LIGHTNING { 64 }
  static SUPERHEALTH { 65536 }
  static KEY1 { 131072 }
  static KEY2 { 262144 }
  static INVISIBILITY { 524288 }
  static INVULNERABILITY { 1048576 }
  static SUIT { 2097152 }
  static QUAD { 4194304 }
}

class Channels {
  static AUTO { 0 }
  static WEAPON { 1 }
  static BODY { 2 }
}

class Attenuations {
  static NONE { 0 }
  static NORMAL { 1 }
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
  static TRIGGER { 1 }
  static BBOX { 2 }
  static SLIDEBOX { 3 }
  static BSP { 4 }
  static CORPSE { 5 }
}

class MoveTypes {
  static NONE { 0 }
  static WALK { 3 }
  static TOSS { 6 }
}

class DeadFlags {
  static NO { 0 }
  static DYING { 1 }
  static DEAD { 2 }
  static RESPAWNABLE { 3 }
}

class Contents {
  static WATER { -3 }
  static SLIME { -4 }
  static LAVA { -5 }
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
