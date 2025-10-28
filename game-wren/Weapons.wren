// Weapons.wren
// Port of the weapon precache routines that worldspawn depends on.

import "./Engine" for Engine

var _WEAPON_SOUNDS = [
  "weapons/r_exp3.wav",
  "weapons/rocket1i.wav",
  "weapons/sgun1.wav",
  "weapons/guncock.wav",
  "weapons/ric1.wav",
  "weapons/ric2.wav",
  "weapons/ric3.wav",
  "weapons/spike2.wav",
  "weapons/tink1.wav",
  "weapons/grenade.wav",
  "weapons/bounce.wav",
  "weapons/shotgn2.wav"
]

class WeaponsModule {
  static precache(globals) {
    for (path in _WEAPON_SOUNDS) {
      Engine.precacheSound(path)
    }
  }
}

