// Subs.wren
// Stubs for utility routines from subs.qc that have not yet been ported.

import "./Engine" for Engine

class SubsModule {
  static useTargets(globals, entity) {
    Engine.log("TODO: SUB_UseTargets is not yet ported to Wren")
  }

  static calcMove(globals, entity, destination, speed, callback) {
    Engine.log("TODO: SUB_CalcMove is not yet ported to Wren")
  }

  static calcAngleMove(globals, entity, destination, speed, callback) {
    Engine.log("TODO: SUB_CalcAngleMove is not yet ported to Wren")
  }

  static attackFinished(globals, entity, normalTime) {
    Engine.log("TODO: SUB_AttackFinished is not yet ported to Wren")
  }

  static checkRefire(globals, entity, thinkFunction) {
    Engine.log("TODO: SUB_CheckRefire is not yet ported to Wren")
  }
}
