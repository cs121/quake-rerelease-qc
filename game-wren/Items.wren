// Items.wren
// Ports core item placement and respawn helpers from items.qc so the
// Wren runtime can manage pickups without falling back to QuakeC.

import "./Engine" for Engine
import "./Globals" for SolidTypes, MoveTypes, PlayerFlags
import "./Globals" for Channels, Attenuations
import "./ItemNames" for ItemNamesModule

class ItemsModule {
  static _ensureNetName(globals, item) {
    if (item == null) return
    var current = item.get("netname", null)
    if (current != null && current != "") return

    var itemsBits = item.get("items", 0)
    if (itemsBits != 0) {
      var name = ItemNamesModule.getNetName(globals, itemsBits)
      if (name != null && name != "") {
        item.set("netname", name)
        return
      }
    }

    var weaponBits = item.get("weapon", 0)
    if (weaponBits != 0) {
      var name = ItemNamesModule.getNetName(globals, weaponBits)
      if (name != null && name != "") {
        item.set("netname", name)
      }
    }
  }

  static subRegen(globals, item) {
    if (item == null) return

    var model = item.get("mdl", item.get("model", ""))
    if (model != null && model != "") {
      item.set("model", model)
      Engine.setModel(item, model)
    }

    item.set("solid", SolidTypes.TRIGGER)
    Engine.playSound(item, Channels.VOICE, "items/itembk2.wav", 1, Attenuations.NORMAL)
    Engine.setOrigin(item, item.get("origin", [0, 0, 0]))
  }

  static SUB_regen(globals, item) { ItemsModule.subRegen(globals, item) }

  static placeItem(globals, item) {
    if (item == null) return

    ItemsModule._ensureNetName(globals, item)
    item.set("mdl", item.get("model", ""))
    item.set("flags", PlayerFlags.ITEM)
    item.set("solid", SolidTypes.TRIGGER)
    item.set("movetype", MoveTypes.TOSS)
    item.set("velocity", [0, 0, 0])

    var origin = item.get("origin", [0, 0, 0])
    origin = [origin[0], origin[1], origin[2] + 6]
    item.set("origin", origin)

    if (!Engine.dropToFloor(item)) {
      Engine.log("Bonus item fell out of level at %(_)." % [item.get("origin", [0, 0, 0])])
      Engine.removeEntity(item)
      return
    }
  }

  static PlaceItem(globals, item) { ItemsModule.placeItem(globals, item) }

  static startItem(globals, item) {
    if (item == null) return

    var nextThink = globals.time + 0.2
    item.set("nextthink", nextThink)
    item.set("think", "ItemsModule.PlaceItem")
    Engine.scheduleThink(item, "ItemsModule.PlaceItem", 0.2)
  }

  static StartItem(globals, item) { ItemsModule.startItem(globals, item) }
}
