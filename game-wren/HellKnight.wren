// HellKnight.wren
// Legacy adapter for the hell knight.

import "./LegacyMonsters" for LegacyMonstersModule

class HellKnightModule {
  static monster_hell_knight(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_hell_knight")
  }
}
