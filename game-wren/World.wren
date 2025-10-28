// World.wren
// Port of the critical world management routines from world.qc.

import "./Engine" for Engine
import "./Globals" for GameGlobals
import "./Entity" for GameEntity

var _CORE_FILES = [
  "progs.dat",
  "gfx.wad",
  "quake.rc",
  "default.cfg",
  "end1.bin",
  "demo1.dem",
  "demo2.dem",
  "demo3.dem",
  "gfx/palette.lmp",
  "gfx/colormap.lmp",
  "gfx/complete.lmp",
  "gfx/inter.lmp",
  "gfx/ranking.lmp",
  "gfx/vidmodes.lmp",
  "gfx/finale.lmp",
  "gfx/conback.lmp",
  "gfx/qplaque.lmp",
  "gfx/menudot1.lmp",
  "gfx/menudot2.lmp",
  "gfx/menudot3.lmp",
  "gfx/menudot4.lmp",
  "gfx/menudot5.lmp",
  "gfx/menudot6.lmp",
  "gfx/menuplyr.lmp",
  "gfx/bigbox.lmp",
  "gfx/dim_modm.lmp",
  "gfx/dim_drct.lmp",
  "gfx/dim_ipx.lmp",
  "gfx/dim_tcp.lmp",
  "gfx/dim_mult.lmp",
  "gfx/mainmenu.lmp",
  "gfx/box_tl.lmp",
  "gfx/box_tm.lmp",
  "gfx/box_tr.lmp",
  "gfx/box_ml.lmp",
  "gfx/box_mm.lmp",
  "gfx/box_mm2.lmp",
  "gfx/box_mr.lmp",
  "gfx/box_bl.lmp",
  "gfx/box_bm.lmp",
  "gfx/box_br.lmp",
  "gfx/sp_menu.lmp",
  "gfx/ttl_sgl.lmp",
  "gfx/ttl_main.lmp",
  "gfx/ttl_cstm.lmp",
  "gfx/mp_menu.lmp",
  "gfx/netmen1.lmp",
  "gfx/netmen2.lmp",
  "gfx/netmen3.lmp",
  "gfx/netmen4.lmp",
  "gfx/netmen5.lmp",
  "gfx/sell.lmp",
  "gfx/help0.lmp",
  "gfx/help1.lmp",
  "gfx/help2.lmp",
  "gfx/help3.lmp",
  "gfx/help4.lmp",
  "gfx/help5.lmp",
  "gfx/pause.lmp",
  "gfx/loading.lmp",
  "gfx/p_option.lmp",
  "gfx/p_load.lmp",
  "gfx/p_save.lmp",
  "gfx/p_multi.lmp",
  "maps/start.bsp",
  "maps/e1m1.bsp",
  "maps/e1m2.bsp",
  "maps/e1m3.bsp",
  "maps/e1m4.bsp",
  "maps/e1m5.bsp",
  "maps/e1m6.bsp",
  "maps/e1m7.bsp",
  "maps/e1m8.bsp"
]

var _SECONDARY_FILES = [
  "end2.bin",
  "gfx/pop.lmp",
  "maps/e2m1.bsp",
  "maps/e2m2.bsp",
  "maps/e2m3.bsp",
  "maps/e2m4.bsp",
  "maps/e2m5.bsp",
  "maps/e2m6.bsp",
  "maps/e2m7.bsp",
  "maps/e3m1.bsp",
  "maps/e3m2.bsp",
  "maps/e3m3.bsp",
  "maps/e3m4.bsp",
  "maps/e3m5.bsp",
  "maps/e3m6.bsp",
  "maps/e3m7.bsp",
  "maps/e4m1.bsp",
  "maps/e4m2.bsp",
  "maps/e4m3.bsp",
  "maps/e4m4.bsp",
  "maps/e4m5.bsp",
  "maps/e4m6.bsp",
  "maps/e4m7.bsp",
  "maps/e4m8.bsp",
  "maps/end.bsp",
  "maps/dm1.bsp",
  "maps/dm2.bsp",
  "maps/dm3.bsp",
  "maps/dm4.bsp",
  "maps/dm5.bsp",
  "maps/dm6.bsp"
]

var _CORE_SOUNDS = [
  "misc/menu1.wav",
  "misc/menu2.wav",
  "misc/menu3.wav",
  "ambience/water1.wav",
  "ambience/wind2.wav"
]

class WorldModule {
  static main(globals) {
    Engine.log("main function")

    for (path in _CORE_FILES) {
      Engine.precacheFile(path)
    }

    for (path in _SECONDARY_FILES) {
      Engine.precacheFile2(path)
    }

    for (path in _CORE_SOUNDS) {
      Engine.precacheSound(path)
    }
  }

  static startFrame(globals) {
    globals.teamplay = Engine.cvar("teamplay")
    globals.skill = Engine.cvar("skill")
    globals.cheatsAllowed = Engine.cvar("sv_cheats")

    if (!globals.campaignValid) {
      globals.campaignValid = true
      globals.campaign = Engine.cvar("campaign")
    } else {
      Engine.cvarSet("campaign", globals.campaign.toString)
    }

    globals.frameCount = globals.frameCount + 1
  }

  static initBodyQueue(globals) {
    var head = Engine.spawnEntity()
    head.set("classname", "bodyqueue")

    var owner1 = Engine.spawnEntity()
    owner1.set("classname", "bodyqueue")
    head.set("owner", owner1)

    var owner2 = Engine.spawnEntity()
    owner2.set("classname", "bodyqueue")
    owner1.set("owner", owner2)

    var owner3 = Engine.spawnEntity()
    owner3.set("classname", "bodyqueue")
    owner2.set("owner", owner3)

    owner3.set("owner", head)

    globals.bodyQueueHead = head
  }

  static copyToBodyQueue(globals, ent) {
    if (globals.bodyQueueHead == null) {
      initBodyQueue(globals)
    }

    var head = globals.bodyQueueHead
    head.set("angles", ent.get("angles", null))
    head.set("model", ent.get("model", null))
    head.set("modelindex", ent.get("modelindex", 0))
    head.set("frame", ent.get("frame", 0))
    head.set("colormap", ent.get("colormap", 0))
    head.set("movetype", ent.get("movetype", 0))
    head.set("velocity", ent.get("velocity", [0, 0, 0]))
    head.set("flags", 0)

    Engine.setOrigin(head, ent.get("origin", [0, 0, 0]))
    Engine.setSize(
      head,
      ent.get("mins", [0, 0, 0]),
      ent.get("maxs", [0, 0, 0])
    )

    globals.bodyQueueHead = head.get("owner", head)
  }
}
