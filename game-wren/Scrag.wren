// Scrag.wren
// Temporary bridge for the scrag (wizard) monster.

import "./LegacyMonsters" for LegacyMonstersModule

class ScragModule {
  static monster_wizard(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_wizard")
  }
}
