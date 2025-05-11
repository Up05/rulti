package rulti

import rl "vendor:raylib"
import "core:math"

PI :: rl.PI

DiagramOptions :: struct {
    overhang: f32,      // The gap same direction arrows leave between the face and arrow

    arrow_head: struct {
        width: f32,
        length: f32,
        groove: f32,     // [0; 1] Proportion of how much the arrow is v instead of ▼
    }
}

DEFAULT_DIAGRAM_OPTIONS : DiagramOptions = {
    overhang = 60,

    arrow_head = {
        width  = 8,
        length = 8,
        groove = 0.6, // this is not mathing that great, but: who cares?
    }
}

// Step :: struct(T: typeid) {
//     userdata : T,
//     root     : ^DiagramRoot,
//     parent   : ^Step,
//     children : [dynamic] Step,
// }

Direction :: enum { RIGHT, DOWN, LEFT, UP }

AngleToDir :: proc(radians: f32) -> Direction {
    // 0 * (PI/2) = RIGHT 
    // 1 * (PI/2) = DOWN
    // 2 * (PI/2) = LEFT
    // 3 * (PI/2) = UP

    coef := radians / (PI/2)
    coef_int := i32(math.round(coef))
    return Direction(coef_int % 4)
}

// direction is in radians (0 to 2PI)
DrawArrowHead :: proc(pos: rl.Vector2, dir: f32, opts := DEFAULT_DIAGRAM_OPTIONS) {
    using opts.arrow_head
    v :: proc(y, x: f32) -> rl.Vector2 { return { x, y } }
    tip  := v(math.sincos_f32(dir))                * length 
    a    := v(math.sincos_f32(dir + (2.0/3.0)*PI)) * length
    back := v(math.sincos_f32(dir - PI))           * length/2 * (groove*2 - 1)
    b    := v(math.sincos_f32(dir - (2.0/3.0)*PI)) * length

    rl.DrawTriangleFan(raw_data([] rl.Vector2 { 
        tip + pos, b + pos, back + pos, a + pos 
    }), 4, rl.BLACK)
}

// ----+
//     |
//     +---->
DrawZagArrow :: proc(a, b: rl.Vector2, a_side, b_side: Direction, opts := DEFAULT_DIAGRAM_OPTIONS) -> (text: rl.Rectangle) {
    using opts

    dx := math.sign(b.x - a.x) // [d]irection not derivative
    dy := math.sign(b.y - a.y)

    X1 := min(a.x, b.x) if dx < 0 else max(a.x, b.x)
    X2 := max(a.x, b.x) if dx < 0 else min(a.x, b.x)
    Y1 := min(a.y, b.y) if dy < 0 else max(a.y, b.y)
    Y2 := max(a.y, b.y) if dy < 0 else min(a.y, b.y)
        
    // Is perpendicular
    if math.abs(i8(a_side) - i8(b_side)) % 2 == 1 {
        rl.DrawLineV({ X1, Y1 }, { X2, Y1 }, rl.BLACK)
        rl.DrawLineV({ X2, Y1 }, { X2, Y2 }, rl.BLACK)
    }

    // Is facing opposite directions
    if math.abs(i8(a_side) - i8(b_side)) == 2 { // this could be an else statement
        is_horizontal := i8(a_side) % 2 == 0 
        
        if is_horizontal {
            X3 := avg(X1, X2)
            
            rl.DrawLineV({ X1, Y1 }, { X3, Y1 }, rl.BLACK)
            rl.DrawLineV({ X3, Y1 }, { X3, Y2 }, rl.BLACK)
            rl.DrawLineV({ X3, Y2 }, { X2, Y2 }, rl.BLACK)
            
        } else {
            Y3 := avg(Y1, Y2)

            rl.DrawLineV({ X1, Y1 }, { X1, Y3 }, rl.BLACK)
            rl.DrawLineV({ X1, Y3 }, { X2, Y3 }, rl.BLACK)
            rl.DrawLineV({ X2, Y3 }, { X2, Y2 }, rl.BLACK)
        }
    }

    // Is facing same direction
    if a_side == b_side {
        is_horizontal := i8(a_side) % 2 == 0 
        
        if is_horizontal {
            X3 := X1 + dx*overhang
            
            rl.DrawLineV({ X2, Y2 }, { X3, Y2 }, rl.BLACK)
            rl.DrawLineV({ X3, Y1 }, { X3, Y2 }, rl.BLACK)
            rl.DrawLineV({ X3, Y1 }, { X1, Y1 }, rl.BLACK)

        } else {
            Y3 := Y1 + dy*overhang

            rl.DrawLineV({ X2, Y2 }, { X2, Y3 }, rl.BLACK)
            rl.DrawLineV({ X2, Y3 }, { X1, Y3 }, rl.BLACK)
            rl.DrawLineV({ X1, Y3 }, { X1, Y1 }, rl.BLACK)
        }
    }


    DrawArrowHead(b, f32(b_side) * (PI/2) + PI)

    return
}


@(private="file")
avg :: proc(a, b: f32) -> f32 {
    return (a + b) / 2
}

