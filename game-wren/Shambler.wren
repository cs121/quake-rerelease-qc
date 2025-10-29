// Shambler.wren
// Legacy adapter for the shambler, forwarding to the QuakeC implementation for
// now.

import "./LegacyMonsters" for LegacyMonstersModule

class ShamblerModule {
  static monster_shambler(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_shambler")
  }
}
