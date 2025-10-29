// Rottweiler.wren
// Legacy adapter for the rottweiler (dog) enemy.

import "./LegacyMonsters" for LegacyMonstersModule

class RottweilerModule {
  static monster_dog(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_dog")
  }
}
