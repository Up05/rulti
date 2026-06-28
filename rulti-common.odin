package rulti

import rl "vendor:raylib"
import "core:fmt"

State :: struct {
    debug  : bool,          // enable debug mode (maybe split this up with a bit_set?)
    mouse  : rl.Vector2,    // position of the mouse with camera and everything already applied
    active : u64,           // ID of the active (top-most hovered) element

    text_options : TextOptions,
    ui_options   : UIOptions,

    _current_id : u64,      // automatic IDs (_current_id += 1) that should reset each frame via: NewFrame()
    _current_static_id : u64, // used for text boxes and scrollbars (does not reset in NewFrame)
}

// Should be called near the start of each frame
NewFrame :: proc(s: ^State, mouse: rl.Vector2) {
    s._current_id = 1
    s.mouse = mouse
}

NextId :: proc(s: ^State) -> u64 {
    defer s._current_id += 1
    return s._current_id
}

NextStaticId :: proc(s: ^State) -> u64 {
    s._current_static_id |= 1000
    defer s._current_static_id += 1
    return s._current_static_id
}

DebugDrawInfo :: proc(pos, size: rl.Vector2, id: u64, s: ^State) {
    if !s.debug { return }

    g := s^
    g.debug = false
    g.text_options.size  = g.text_options.size / 2
    g.text_options.color = ColorFromHex(0x33AA33FF)
    g.text_options.background = rl.BLANK

    id       := fmt.tprint(id)
    id_size  := MeasureTextLine(id, &g) - { g.text_options.spacing, 0 }
    box_size := rl.Vector2 { max(id_size.x + 8, id_size.y + 4), id_size.y + 4 }

    rl.DrawRectangleLinesEx(rect(pos,                   size),     1, g.text_options.color)
    rl.DrawRectangleRec    (rect(pos + size - box_size, box_size),    ColorFromHex(0x222222FF))
    rl.DrawRectangleLinesEx(rect(pos + size - box_size, box_size), 1, g.text_options.color)
    DrawTextBasic(id, pos + size - { box_size.x/2 + id_size.x/2, id_size.y}, &g)

    rect :: proc(pos, size: rl.Vector2) -> rl.Rectangle { return { pos.x, pos.y, size.x, size.y } }
}

// This is an unnecessary (and slow) helper! Also, allocates on temp_allocator...
// It allows you to change an option without creating a temporary variable. 
// DrawTextBasic("some text", {}, With(text_options, color = hex(0xFF77000FF)))
With :: proc(base: ^State, 
             _for_forcing_named_parameters: ..struct{},
             font         : Maybe(type_of(base.text_options.font        )) = nil,
             size         : Maybe(type_of(base.text_options.size        )) = nil,
             spacing      : Maybe(type_of(base.text_options.spacing     )) = nil,
             line_spacing : Maybe(type_of(base.text_options.line_spacing)) = nil,
             center_x     : Maybe(type_of(base.text_options.center_x    )) = nil,
             center_y     : Maybe(type_of(base.text_options.center_y    )) = nil,
             selectable   : Maybe(type_of(base.text_options.selectable  )) = nil,
             color        : Maybe(type_of(base.text_options.color       )) = nil,
             background   : Maybe(type_of(base.text_options.background  )) = nil,
    ) -> ^State {
    
    new := new_clone(base^, context.temp_allocator)

    new.text_options.font         = font         .? or_else new.text_options.font         
    new.text_options.size         = size         .? or_else new.text_options.size         
    new.text_options.spacing      = spacing      .? or_else new.text_options.spacing      
    new.text_options.line_spacing = line_spacing .? or_else new.text_options.line_spacing 
    new.text_options.center_x     = center_x     .? or_else new.text_options.center_x     
    new.text_options.center_y     = center_y     .? or_else new.text_options.center_y     
    new.text_options.selectable   = selectable   .? or_else new.text_options.selectable   
    new.text_options.color        = color        .? or_else new.text_options.color        
    new.text_options.background   = background   .? or_else new.text_options.background   

    return new
}
