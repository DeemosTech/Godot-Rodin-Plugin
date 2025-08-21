@tool
class_name RBCtx extends Node

static func instance() -> RBCtx:
    return RBSettings.fetch("ctx_inst")

var material_config := {}
var config := {}
var condition_type := ""
