package rulti

import rl "vendor:raylib"

import "core:math"
import "core:math/linalg"

DrawCapsule :: proc(p1, p2: rl.Vector2, radius: f32, segments : int, color: rl.Color) {
	dir := p2 - p1
	len := linalg.length(dir)
	if len == 0.0 {
		rl.DrawCircleV(p1, radius, color)
		return
	}
	norm := dir / len
	tangent := [2]f32{-norm[1], norm[0]}
	angle := math.atan2(norm[1], norm[0]) * (180.0 / math.PI) // degrees

	offset := tangent * radius
	v1 := p1 + offset
	v2 := p1 - offset
	v3 := p2 - offset
	v4 := p2 + offset

	rl.DrawTriangle(v3, v2, v1, color)
	rl.DrawTriangle(v1, v4, v3, color)

	rl.DrawCircleSector(
		cast(rl.Vector2)p1,
		radius,
		angle + 270.0,
		angle + 90.0,
		i32(segments),
		color
	)

	rl.DrawCircleSector(
		cast(rl.Vector2)p2,
		radius,
		angle - 90.0,
		angle + 90.0,
		i32(segments),
		color
	)
}
