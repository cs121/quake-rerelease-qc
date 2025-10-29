// Fiend.wren
// Legacy bridge for the fiend (demon) monster, delegating to QuakeC until a
// full Wren rewrite is complete.

import "./LegacyMonsters" for LegacyMonstersModule

class FiendModule {
  static monster_demon1(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_demon1")
  }
}
