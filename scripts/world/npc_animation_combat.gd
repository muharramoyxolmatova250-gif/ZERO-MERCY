extends RefCounted
## Readable stance offsets for combat states; gameplay hit detection remains elsewhere.
const STANCES := {
	"unarmed":{"guard":0.62,"lean":0.09,"arm_spread":0.10},
	"aiming":{"guard":0.82,"lean":0.16,"arm_spread":0.04},
	"reloading":{"guard":0.35,"lean":0.02,"arm_spread":0.18},
	"staggered":{"guard":0.12,"lean":-0.16,"arm_spread":0.32},
	"recovering":{"guard":0.42,"lean":0.04,"arm_spread":0.12}
}
static func get_stance(name: String) -> Dictionary:
	return STANCES.get(name, {}).duplicate(true)
