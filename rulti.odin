package rulti

import rl "vendor:raylib"

TextOptions :: struct {
    font         : rl.Font,
    size         : f32,
    spacing      : f32,
    line_spacing : f32,         
    tab_width    : f32,         // tab shift character max width

    center_x     : bool,        // whether to center horizontally
    center_y     : bool,        // whether to center  verticallly
    selectable   : bool,        // whether text is selectable with the mouse

    color        : rl.Color,    // the text character color
    background   : rl.Color,    // tightly wrapped
    highlight    : rl.Color,    // text selection color

    camera       : ^rl.Camera2D,// set this if selectable = true and text is drawn in BeginMode2D(...)
}

// May be changed
DEFAULT_TEXT_OPTIONS : TextOptions = {
    font         = rl.GetFontDefault(),
    size         = 24,
    spacing      = 1,
    line_spacing = 2,
    tab_width    = 24*4,
    center_x     = true,
    center_y     = true,
    color        = rl.BLACK,
    background   = {},
    highlight    = { 180, 215, 255, 255 },
    camera       = nil,
}

// Currently selected text
// (If you are not sure about your memory, clone this string)
selection: string
selection_in_progress: bool

// these are much more volatile
@(private="file") 
sel_start: int 
@(private="file") // btw, sel_end can be less than sel_start
sel_end  : int
@(private="file")
sel_id   : u64

MeasureRune :: proc(r: rune, pos: rl.Vector2 = {}, opts := DEFAULT_TEXT_OPTIONS) -> (advance: rl.Vector2) {
    // Extra sh*t
    opts := opts
    using opts
    if font.texture.id == 0 do font = rl.GetFontDefault()
    if r < ' ' && r != '\t' do return
    scaling := size / f32(font.baseSize)

    // Advance
    glyph := rl.GetGlyphIndex(font, r)
    advance1 := f32(font.glyphs[glyph].advanceX)
    advance.x += (advance1 if advance1 != 0 else font.recs[glyph].width) * scaling + spacing
    if r == '\t' {
        advance.x += tab_width - f32(i32(pos.x + advance.x)%i32(tab_width))
    }
    advance.y = size + line_spacing
    return
}

DrawTextLine :: proc(text: string, pos: rl.Vector2, opts := DEFAULT_TEXT_OPTIONS) {
    opts := opts
    using opts
    if font.texture.id == 0 do font = rl.GetFontDefault()
    
    scaling := size / f32(font.baseSize)
    offset: vec
    for r, i in text {
        if r < ' ' && r != '\t' do continue
        rl.DrawTextCodepoint(font, r, pos + offset, size, color)
                
        glyph := rl.GetGlyphIndex(font, r)
        advance := f32(font.glyphs[glyph].advanceX)
        offset.x += (advance if advance != 0 else font.recs[glyph].width) * scaling + spacing
        if r == '\t' {
            offset.x += tab_width - f32(i32(pos.x + offset.x)%i32(tab_width))
        }
    }
}

// don't worry about x_pos_for_tab too much, especially for centered text
// because I just do not believe that a text that is centered would ever contain tabs. 
MeasureTextLine :: proc(text: string, x_pos_for_tab : f32 = 0, opts := DEFAULT_TEXT_OPTIONS) -> (text_size: vec) {
    using opts

    assert(font.texture.id != 0, "MeasureText was given a bad font")
    if len(text) == 0 do return 
    
    scaling := size / f32(font.baseSize)
    
    for r, i in text {
        if r < ' ' && r != '\t' do continue
        glyph := rl.GetGlyphIndex(font, r)
        advance := f32(font.glyphs[glyph].advanceX)
        text_size.x += (advance if advance != 0 else font.recs[glyph].width) * scaling + spacing
        if r == '\t' {
            text_size.x += tab_width - f32(i32(x_pos_for_tab + text_size.x)%i32(tab_width))
        }
    }

    text_size.y = size + line_spacing
    return
}

DrawTextWrapped :: proc(text: string, pos: rl.Vector2, box_size: rl.Vector2, 
                        opts := DEFAULT_TEXT_OPTIONS) -> (new_size: vec) {
    using opts
    
    original_text := text
    text  := text
    lines := make([dynamic] string, context.allocator)
    defer delete(lines)

    cursor : int
    pcursor: int // prev cursor
    for {
        cursor = find_space_from(text, cursor + 1)
        defer pcursor = cursor
        
        chunk_size := MeasureTextLine(text[:cursor], pos.x, opts)

        // Automatic text wrapping
        if chunk_size.x >= box_size.x {
            // Single word wrapping
            if pcursor == 0 {
                x: f32
                p: int // previous i
                i: int
                for ; i < len(text[:cursor]); i += 1 { // fix this to support utf8
                    x += MeasureTextLine(text[i:i+1]).x
                    if x > box_size.x {
                        append(&lines, text[p:i])
                        p = i + 1
                        x = 0
                    }
                }

                append(&lines, text[p:cursor])
                text = text[cursor:]
            } else {
                // Wrapping over non-printable characters & space
                append(&lines, text[:pcursor])
                text = text[pcursor + 1:]
            }
            pcursor = 0
            cursor = 0
        }

        // New line characters
        if cursor < len(text) {
            if text[cursor] == '\r' { // Windows: \r\n
                append(&lines, text[:cursor])
                text = text[cursor + 1:]
                pcursor = 0
                cursor  = 0

                // For ..<macOS 9 remove '+ 1' on line with 'text ='
                // and uncomment this line:
                // if 1 < len(text) && text[1] == '\n' do text = text[1:] 

            } else if text[cursor] == '\n' { // Else: \n
                append(&lines, text[:cursor])
                text = text[cursor:]
                pcursor = 0
                cursor  = 0
            }
        }
        
        if cursor >= len(text) - 1 {
            append(&lines, text)
            break
        }
    }
    
    // Drawing + selection

    is_mouse_start   := rl.IsMouseButtonPressed(.LEFT)
    is_mouse_ongoing := rl.IsMouseButtonDown(.LEFT)

    id := transmute(u64) raw_data(original_text)

    if  sel_id == id &&
        is_mouse_start {
        sel_id = 0
        sel_start, sel_end = 0, 0
        selection_in_progress = false
    }

    cam: rl.Camera2D = camera^ if camera != nil else { zoom = 1 }
    mouse := rl.GetScreenToWorld2D(rl.GetMousePosition(), cam)

    pos := pos
    rune_index: int
    // Drawing lines 
    for line, line_index in lines {
        defer rune_index += len(line)
        chunk_size := MeasureTextLine(line, pos.x, opts)
        
        o: vec // offset

        o.x = (box_size.x - chunk_size.x) / 2 if center_x else 0
        o.y = (box_size.y - (size + line_spacing) * f32(len(lines))) / 2 + size/2 if center_y else 0
        o.y += f32(line_index) * ( size + line_spacing )

        // Drawing individual characters 
        for r, i in line {
            advance := MeasureRune(r, pos + o)
            if advance == {} do continue

            //  Checking for mouse highlighting    ( this is all slow :< )
            if  mouse.x >= pos.x + o.x && mouse.x <= pos.x + o.x + advance.x && 
                mouse.y >= pos.y + o.y && mouse.y <= pos.y + o.y + advance.y {
                
                if is_mouse_start {
                    sel_id = id
                    sel_start = rune_index + i
                    selection_in_progress = true
                } else if is_mouse_ongoing {
                    if sel_id == id {
                        sel_end   = rune_index + i
                        selection = original_text[min(sel_start, sel_end):max(sel_start, sel_end)]
                        selection_in_progress = true
                    }
                }
            }

            if  sel_id == id &&
                rune_index + i >= min(sel_start, sel_end) && 
                rune_index + i <= max(sel_start, sel_end) {
               rl.DrawRectangleV(pos + o, advance, highlight) 
            } else {
               rl.DrawRectangleV(pos + o, advance, background) 
            }

            rl.DrawTextCodepoint(font, r, floor_vec(pos + o), size, color)
            
            o.x += advance.x
        }
        
    }

    return
}


@(private="file")
// Text looks better when it is drawn aligned to the nearest pixel
floor_vec :: proc(pos: vec) -> vec {
    return { f32(i32(pos.x)), f32(i32(pos.y)) }
}

@(private="file")
find_space_from :: proc(str: string, offset: int) -> int {
    if offset >= len(str) do return len(str)
    for r, i in str[offset:] {
        if r <= ' ' do return i + offset
    }
    return len(str)
}
