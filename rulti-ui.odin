package rulti

import rl "vendor:raylib"
import "core:math/rand"

/**
    This file contains addons to raylib 
    that may come in handy when making UI.
    
    1.  Scroll         structure  Scroll { max = { ... } } to initialize a scrollbar
        DrawScrollbar  procedure  Draws and updates a scrollbar
                                  use: button_pos := pos - scroll.pos
 
    2.  ColorFromHex  procedure  converts the 0xFF00FFFF colors to raylib.Color
        gruvbox       variable   contains all of the (original?) gruvbox colorscheme
    
    3.  DrawBorderInset   procedure  Draws an "embedded" border
        DrawBorderOutset  procedure  Draws a  "popped" border

    And by the way, roll the layout yourself or whatever...
*/

// Convert: 0xRRGGBBAA to raylib.Color
// do not forget to speficy alpha! zero is zero.
ColorFromHex :: proc(hex: u32) -> rl.Color {
    assert(hex >= 0 && hex <= 0xFFFFFFFF)
    r : u8 = u8( (hex & 0xFF000000) >> 24 )
    g : u8 = u8( (hex & 0x00FF0000) >> 16 )
    b : u8 = u8( (hex & 0x0000FF00) >>  8 )
    a : u8 = u8( (hex & 0x000000FF) )
    return { r, g, b, a }
}

GruvboxPalette :: enum {
    FG0, FG1, FG2, FG3, FG4,
    BG0, BG1, BG2, BG3, BG4,
    BG0_HARD, BG0_SOFT,

    RED1,    RED2,      GREEN1,  GREEN2,
    YELLOW1, YELLOW2,   BLUE1,   BLUE2,
    PURPLE1, PURPLE2,   AQUA1,   AQUA2,
    GRAY1,   GRAY2,     ORANGE1, ORANGE2
}

// The palette is taken from morhetz/gruvbox repo:
// https://github.com/morhetz/gruvbox
// a recreation of gruvbox-dark, mainly, for me...
gruvbox : [GruvboxPalette] rl.Color = {
    .BG0_HARD = ColorFromHex(0x1D2021FF),
    .BG0_SOFT = ColorFromHex(0x32302FFF),

    .BG0 = ColorFromHex(0x282828FF),
    .BG1 = ColorFromHex(0x3C3836FF),
    .BG2 = ColorFromHex(0x504945FF),
    .BG3 = ColorFromHex(0x504945FF),
    .BG4 = ColorFromHex(0x665C54FF),
    .FG0 = ColorFromHex(0xFBF1C7FF),
    .FG1 = ColorFromHex(0xEBDBB2FF),
    .FG2 = ColorFromHex(0xD5C4A1FF),
    .FG3 = ColorFromHex(0xBDAE93FF),
    .FG4 = ColorFromHex(0xA89984FF),

    .RED1    = ColorFromHex(0xCC241DFF),
    .RED2    = ColorFromHex(0xFB4934FF),
    .GREEN1  = ColorFromHex(0x98971AFF),
    .GREEN2  = ColorFromHex(0xB8BB26FF),
    .YELLOW1 = ColorFromHex(0xD79921FF),
    .YELLOW2 = ColorFromHex(0xFABD2FFF),
    .BLUE1   = ColorFromHex(0x458588FF),
    .BLUE2   = ColorFromHex(0x83A598FF),
    .PURPLE1 = ColorFromHex(0xB16286FF),
    .PURPLE2 = ColorFromHex(0xD3869BFF),
    .AQUA1   = ColorFromHex(0x689D6AFF),
    .AQUA2   = ColorFromHex(0x8EC07CFF),
    .GRAY1   = ColorFromHex(0x928374FF),
    .GRAY2   = ColorFromHex(0xA89984FF),
    .ORANGE1 = ColorFromHex(0xD65D0EFF),
    .ORANGE2 = ColorFromHex(0xFE8019FF),
}

UIOptions :: struct {
    camera : ^rl.Camera2D,
    scroll : struct {
        width          : f32,
        track_bg       : rl.Color,
        thumb_bg       : rl.Color,
        corner_bg      : rl.Color, // if both vertical and horizontal bars are visible
        border_dark    : rl.Color,
        border_bright  : rl.Color,
        speed_maintain : f32,
        speed          : f32,
    }
}

DEFAULT_UI_OPTIONS : UIOptions = {
    scroll = {
        width           = 20,
        track_bg        = rl.GRAY,
        thumb_bg        = rl.LIGHTGRAY,
        corner_bg       = rl.GRAY - 32,
        border_dark     = rl.WHITE,
        border_bright   = rl.BLACK,
        speed_maintain  = 0.825,
        speed           = 20,
    }
}

Scroll :: struct {
    pos, vel  : rl.Vector2,
    max       : rl.Vector2,
    id        : u64,
}

@private
dragged_scrollbar_id: u64
@private
dragged_scrollbar_horizontal: bool

@private
TryMakeScrollbarActive :: proc(scroll: Scroll, track: rl.Rectangle, opts: UIOptions) -> bool {
    scroll := scroll
    mouse := rl.GetMousePosition()
    mouse  = rl.GetScreenToWorld2D(mouse, opts.camera^) if opts.camera != nil else mouse

    if rl.IsMouseButtonPressed(.LEFT) && rl.CheckCollisionPointRec(mouse, track) {
        dragged_scrollbar_id = scroll.id
        return true
    } 
    return false
}

// The Scroll struct technically has 2 scrollbars: vertical & horizontal
// specify `horizontal = true`, and only the horizontal scrollbar will be checked...
IsScrollbarDragged :: proc(scroll: Scroll, horizontal: bool) -> bool {
    if dragged_scrollbar_horizontal != horizontal do return false
    return scroll.id == dragged_scrollbar_id 
}

IsAnyScrollbarDragged :: proc() -> bool { return dragged_scrollbar_id != 0 }

// Draws the scrollbar (you may simply call this every frame for every scrollbar...)
//                 opts.scroll.width╶┬──┐
//     pos -> ┌──────────────────────┬──┐  1. There is also a                       
//            │  Some text           ┝━━┥     horizontal scrollbar
//            │  that does           │  │  2. Mouse cursor should be between
//            │  not                 │══│     pos & pos+size
//            │  fit                 │  │  3. If camera2D.target is changed    
//            │  the                 ┝━━┥     set it in UIOptions
//            │  box                 │  │  
//            │  vertically          │  │
//            ├──────────────────────┴──┤ <- pos + size
//            ╎  and goes off-screen    ╎                         
//            └╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶┘ <- pos + max
DrawScrollbar :: proc(scroll: ^Scroll, pos: rl.Vector2, size: rl.Vector2, opts := DEFAULT_UI_OPTIONS) {
    assert(scroll != nil)

    base_opts := opts
    opts      := opts.scroll

    UpdateScrollbar(scroll, pos, size, base_opts)

    draw_vertical   := scroll.max.y != 0 && scroll.max.y > size.y  
    draw_horizontal := scroll.max.x != 0 && scroll.max.x > size.x 

    if draw_vertical { 
        track_pos  : rl.Vector2 = pos + { size.x - opts.width, 0 }
        track_size : rl.Vector2 = { opts.width, size.y - (opts.width if draw_horizontal else 0) }

        if TryMakeScrollbarActive(scroll^, { track_pos.x, track_pos.y, track_size.x, track_size.y }, base_opts) { 
            dragged_scrollbar_horizontal = false // mild spaghetti
        }

        fraction     := f32(scroll.pos.y) / f32(scroll.max.y)
        thumb_offset := track_size.y * fraction + track_pos.y
        thumb_height := track_size.y*track_size.y * (1/scroll.max.y)
        
        if thumb_offset-track_pos.y + thumb_height > track_size.y {
            thumb_height = max(track_size.y - (thumb_offset-track_pos.y), 0)
        }

        rl.DrawRectangleV(track_pos, track_size, opts.track_bg)
        rl.DrawRectangleV({ track_pos.x, thumb_offset }, { track_size.x, thumb_height }, opts.thumb_bg)
        DrawBorderInset(track_pos, track_size, rl.BLACK, rl.LIGHTGRAY - 32)
    }

    if draw_horizontal { 
        track_pos  : rl.Vector2 = pos + { 0, size.y - opts.width }
        track_size : rl.Vector2 = { size.x - (opts.width if draw_vertical else 0), opts.width }

        if TryMakeScrollbarActive(scroll^, { track_pos.x, track_pos.y, track_size.x, track_size.y }, base_opts) { 
            dragged_scrollbar_horizontal = true
        }

        fraction     := f32(scroll.pos.x) / f32(scroll.max.x)
        thumb_offset := track_size.x * fraction + track_pos.x
        thumb_width  := track_size.x*track_size.x * (1/scroll.max.x)

        if thumb_offset-track_pos.x + thumb_width > track_size.x {
            thumb_width = max(track_size.x - (thumb_offset-track_pos.x), 0)
        }

        rl.DrawRectangleV(track_pos, track_size, opts.track_bg)
        rl.DrawRectangleV({ thumb_offset, track_pos.y }, { thumb_width, track_size.y }, opts.thumb_bg)
        DrawBorderInset(track_pos, track_size, opts.border_dark, opts.border_bright)
    }

    if draw_vertical && draw_horizontal {
        rl.DrawRectangleV(pos + size - opts.width, opts.width, opts.corner_bg)
    }

}


// You may call this manually (every frame), 
// if you only want mouse/... scrolling
// but for scrollbars themselves to be hidden
UpdateScrollbar :: proc(scroll: ^Scroll, pos: rl.Vector2, size: rl.Vector2, opts := DEFAULT_UI_OPTIONS) {
    assert(scroll != nil)
    if scroll.id == 0 { scroll.id = rand.uint64() }

    if rl.IsMouseButtonUp(.LEFT) {
        dragged_scrollbar_id = 0
    }

    mouse := rl.GetMousePosition()
    mouse  = rl.GetScreenToWorld2D(mouse, opts.camera^) if opts.camera != nil else mouse

    if IsScrollbarDragged(scroll^, false) {
        
        track_pos  : rl.Vector2 = pos + { opts.scroll.width, 0 }
        track_size : rl.Vector2 = { opts.scroll.width, size.y }

        thumb_height := track_size.y*track_size.y * (1/scroll.max.y)
        scroll.pos.y = (mouse.y - track_pos.y - thumb_height/2) / track_size.y / (1/scroll.max.y)
    
    } else if IsScrollbarDragged(scroll^, true) {

        track_pos  : rl.Vector2 = pos + { 0, opts.scroll.width }
        track_size : rl.Vector2 = { size.x, opts.scroll.width }

        thumb_width := track_size.x*track_size.x * (1/scroll.max.x)
        scroll.pos.x = (mouse.x - track_pos.x - thumb_width/2) / track_size.x / (1/scroll.max.x)
    
    } else if rl.CheckCollisionPointRec(mouse, { pos.x, pos.y, size.x, size.y }) {
        
        vel := -rl.GetMouseWheelMoveV()
        if rl.IsKeyDown(.LEFT_SHIFT) {
            vel.x = vel.x if vel.x != 0 else vel.y
            vel.y = 0
        }

        scroll.vel += vel * opts.scroll.speed
    
    }

    scroll.pos  += scroll.vel
    scroll.pos.x = max(scroll.pos.x, 0)
    scroll.pos.y = max(scroll.pos.y, 0)
    scroll.vel  *= opts.scroll.speed_maintain // 0..<1

    end := scroll.max * 0.95
    scroll.pos = { max(scroll.pos.x, 0),     max(scroll.pos.y, 0) }
    scroll.pos = { min(scroll.pos.x, end.x), min(scroll.pos.y, end.y) }

}
   
   


// 🭽▔▌ Draws a two color border, where bottom-right sides are brighter
// 🬂🬂🬀 this makes the rectangle look like it is embedded into ...
DrawBorderInset :: proc(pos, size: rl.Vector2, darker, brighter: rl.Color, thicker := false) {
    
    A : [3] rl.Vector2 = {
        pos + { size.x, 0 },    // 1---0
        pos,                    // |    
        pos + { 0, size.y },    // 2    
    }

    B : [3] rl.Vector2 = {
        pos + { size.x, 0},     //     0
        pos + size,             //     |
        pos + { 0, size.y },    // 2---1
    }

    rl.DrawLineStrip(cast([^] rl.Vector2) &A, 3, darker)
    rl.DrawLineStrip(cast([^] rl.Vector2) &B, 3, brighter)

    if thicker { 
        A.xyz += 0.5
        B.xyz -= 0.5
        
        rl.DrawLineStrip(cast([^] rl.Vector2) &A, 3, darker)
        rl.DrawLineStrip(cast([^] rl.Vector2) &B, 3, brighter)
    }
}

// 🬞🬭🬭 Draws a two color border, where top-left sides are brighter
// 🮉▁🭿 this makes the rectangle look like it pops out of ...
DrawBorderOutset :: proc(pos, size: rl.Vector2, darker, brighter: rl.Color, thicker := false) {
    DrawBorderInset(pos, size, brighter, darker, thicker)
}
