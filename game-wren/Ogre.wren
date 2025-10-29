// Ogre.wren
// Temporary bridge that routes ogre behavior through the legacy QuakeC
// implementation until a native Wren port is available.

import "./LegacyMonsters" for LegacyMonstersModule

class OgreModule {
  static monster_ogre(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_ogre")
  }

  static monster_ogre_marksman(globals, monster) {
    LegacyMonstersModule.spawn(globals, monster, "qc_monster_ogre_marksman")
  }
}
