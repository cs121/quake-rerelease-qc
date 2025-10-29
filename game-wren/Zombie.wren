// Zombie.wren
// Legacy adapter for zombies while a full Wren implementation is prepared.

import "./LegacyMonsters" for LegacyMonstersModule

class ZombieModule {
  static monster_zombie(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_zombie")
  }
}
