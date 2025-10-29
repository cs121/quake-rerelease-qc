// Enforcer.wren
// Legacy adapter for the enforcer enemy.

import "./LegacyMonsters" for LegacyMonstersModule

class EnforcerModule {
  static monster_enforcer(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_enforcer")
  }
}
