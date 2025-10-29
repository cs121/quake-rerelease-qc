// Vore.wren
// Legacy adapter for the vore (shalrath) monster.

import "./LegacyMonsters" for LegacyMonstersModule

class VoreModule {
  static monster_shalrath(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_shalrath")
  }
}
