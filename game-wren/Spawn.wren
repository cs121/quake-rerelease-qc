// Spawn.wren
// Legacy adapter for the tarbaby (spawn) enemy.

import "./LegacyMonsters" for LegacyMonstersModule

class SpawnModule {
  static monster_tarbaby(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_tarbaby")
  }
}
