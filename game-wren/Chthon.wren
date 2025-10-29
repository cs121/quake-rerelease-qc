// Chthon.wren
// Legacy adapter for Chthon, delegating boss behavior to QuakeC for now.

import "./LegacyMonsters" for LegacyMonstersModule

class ChthonModule {
  static monster_boss(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_boss")
  }
}
