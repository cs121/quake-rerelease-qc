// Shub.wren
// Legacy adapter for Shub-Niggurath.

import "./LegacyMonsters" for LegacyMonstersModule

class ShubModule {
  static monster_oldone(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_oldone")
  }
}
