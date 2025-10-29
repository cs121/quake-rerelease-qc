// Grunt.wren
// Legacy adapter for the grunt (Grunts/Army) enemy.

import "./LegacyMonsters" for LegacyMonstersModule

class GruntModule {
  static monster_army(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_army")
  }
}
