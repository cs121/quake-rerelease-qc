// Rotfish.wren
// Legacy adapter for swimming rotfish enemies.

import "./LegacyMonsters" for LegacyMonstersModule

class RotfishModule {
  static monster_fish(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_fish")
  }
}
