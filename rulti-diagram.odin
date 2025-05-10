package rulti

import rl "vendor:raylib"
import "core:math"
import "core:fmt"

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



}

// Step :: struct(T: typeid) {
//     userdata : T,
//     root     : ^DiagramRoot,
//     parent   : ^Step,
//     children : [dynamic] Step,
// }

Direction :: enum { RIGHT, DOWN, LEFT, UP }

AngleToDir :: proc(radians: f32) -> Direction {
    // cast(Direction)  0 * (PI/2) = RIGHT 
    // cast(Direction)  1 * (PI/2) = DOWN
    // cast(Direction)  2 * (PI/2) = LEFT
    // cast(Direction)  3 * (PI/2) = UP

    PI :: 3.14159265358979323846
    
    coef := radians / (PI/2)
    coef_int := i32(math.round(coef))
    DrawTextBasic(fmt.aprint(Direction(coef_int % 4)), { 550, 500 })
    return Direction(coef_int % 4)
}

// direction is in radians (0 to 2PI)
DrawArrowHead :: proc(pos: rl.Vector2, dir: f32) {
    

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
    return
}


@(private="file")
avg :: proc(a, b: f32) -> f32 {
    return (a + b) / 2
}

