#+feature using-stmt
package rulti

import rl "vendor:raylib"
import "core:fmt"

TextOptions :: struct {
    fallback_fonts : [dynamic; #config(RULTI_MAX_FALLBACK_FONTS, 8)] rl.Font,
    font           : rl.Font,
    size           : f32,
    spacing        : f32,
    line_spacing   : f32,         

    center_x       : bool,         // whether to center horizontally
    center_y       : bool,         // whether to center  verticallly
    selectable     : bool,         // whether text is selectable with the mouse

    color          : rl.Color,     // the text character color
    background     : rl.Color,     // tightly wrapped
    highlight      : rl.Color,     // text selection color
}

// May be changed
DEFAULT_TEXT_OPTIONS : TextOptions = {
    font         = rl.GetFontDefault(),
    size         = 24,
    spacing      = 1,
    line_spacing = 2,
    center_x     = false,
    center_y     = false,
    color        = rl.BLACK,
    background   = {},
    highlight    = { 180, 215, 255, 255 },
}

// Currently selected text
// (If you are not sure about your memory, clone this string)
selection: string
selection_in_progress: bool

// These are much more volatile
@(private) sel_start : int 
@(private) sel_end   : int // btw, sel_end can be less than sel_start 
@(private) sel_id    : u64

GetFontWithRune :: proc(r: rune, s: ^State) -> (font: rl.Font, ok: bool) {
    opts := s.text_options
    glyph := rl.GetGlyphIndex(opts.font, r)
    if opts.font.glyphs[glyph].image.data != nil {
        return opts.font, true
    }

    for font in opts.fallback_fonts[:] {
        glyph := rl.GetGlyphIndex(font, r)
        if font.glyphs[glyph].image.data != nil {
            return font, true
        }
    }

    return {}, false
}


// Returns the size of a rune accounted for TextOptions.
// '\n' and other non-printable ascii chars are ignored.
MeasureRune :: proc(r: rune, s: ^State) -> (advance: rl.Vector2) {
    opts := s.text_options
    if r < ' ' do return

    font, can_draw := GetFontWithRune(r, s)
    if !can_draw { return { opts.size * (2.0/3) + opts.spacing, opts.size + opts.line_spacing } }

    scaling := opts.size / f32(font.baseSize)
    
    // Advance
    glyph := rl.GetGlyphIndex(font, r)
    advance1 := f32(font.glyphs[glyph].advanceX)
    advance.x += (advance1 if advance1 != 0 else font.recs[glyph].width) * scaling + opts.spacing
    advance.y = opts.size + opts.line_spacing

    return
}

// y component is a line + it's advance even if given an empty string
// x component may be zero
// '\n' are ignored.
MeasureTextLine :: proc(text: string, s: ^State) -> (text_size: rl.Vector2) {
    opts := s.text_options
    for r, i in text { text_size += MeasureRune(r, s) }
    text_size.y = opts.size + opts.line_spacing
    return
}

// y component is a line + it's advance even if given an empty string
// x component may be zero
MeasureTextWrapped :: proc(text: string, box_size: rl.Vector2, s: ^State) -> (size: rl.Vector2) {
    opts := s.text_options
    if box_size == {} do return
    lines := SplitTextIntoLines(text, box_size, s)

    winner_len: int
    #no_bounds_check for line in lines {
        line_size := MeasureTextLine(line, s)
        size.x     = max(size.x, line_size.x)
        winner_len = max(winner_len, len(line))
    }
    size.y = f32(len(lines)) * ( opts.size + opts.line_spacing )
    return
}

DrawRune :: proc(r: rune, pos: rl.Vector2, s: ^State) {
    opts := s.text_options

    font, can_draw := GetFontWithRune(r, s)
    if !can_draw {
        rl.DrawRectangleLinesEx({ pos.x, pos.y, opts.size * (2.0/3), opts.size }, 1, opts.color)
        return
    }

    rl.DrawTextCodepoint(font, r, pos, opts.size, opts.color)
}


// Draws a single line text. No centering, selection or '\n' handling.
DrawTextBasic :: proc(text: string, pos: rl.Vector2, s: ^State, id: u64 = 0) -> (text_size: rl.Vector2) {
    opts := s.text_options
        
    // Selection
    is_mouse_start   := rl.IsMouseButtonPressed(.LEFT)
    is_mouse_ongoing := rl.IsMouseButtonDown(.LEFT)

    id := id if id != 0 || !opts.selectable else NextId(s)

    if sel_id == id && is_mouse_start {
        sel_id = 0
        sel_start, sel_end = 0, 0
        selection_in_progress = false
    }
    
    offset: rl.Vector2
    for r, i in text {
        if r < ' ' do continue

        rl.DrawRectangleV(pos + offset, MeasureRune(r, s), opts.background)
        DrawRune(r, pos + offset, s)
                
        advance  := MeasureRune(r, s).x
        offset.x += advance

        //  Checking for mouse highlighting 
        ax := pos.x + offset.x - advance
        bx := advance
        if opts.selectable && rl.CheckCollisionPointRec(s.mouse, { ax, pos.y, bx, opts.size }) {
            
            if is_mouse_start {
                sel_id = id
                sel_start = i
                sel_end   = i
                selection_in_progress = true
            } else if is_mouse_ongoing && sel_id == id {
                sel_end = i
                selection = text[min(sel_start, sel_end):max(sel_start, sel_end)]
                selection_in_progress = true
            }
        }
    }
    
    if opts.selectable { // && state.active == id
        pmouse := s.mouse - rl.GetMouseDelta()
        a := rl.CheckCollisionPointRec(pmouse,  { pos.x, pos.y, offset.x, opts.size + opts.line_spacing })
        b := rl.CheckCollisionPointRec(s.mouse, { pos.x, pos.y, offset.x, opts.size + opts.line_spacing })
        if !a && b { rl.SetMouseCursor(.IBEAM) }
        if a && !b { rl.SetMouseCursor(.DEFAULT) }
    }

    if opts.selectable { DebugDrawInfo(pos, { offset.x, opts.size + opts.line_spacing }, id, s) }

    return { offset.x, opts.size + opts.line_spacing }
}

// Less useful for user. Wraps text into new lines.
SplitTextIntoLines :: proc(text: string, box_size: rl.Vector2, s: ^State) -> (lines: [dynamic] string) {
    opts := s.text_options
    text := text
    lines = make([dynamic] string, context.allocator)
    cursor : int
    pcursor: int // previous cursor
    for {
        cursor = find_space_from(text, cursor + 1)
        defer pcursor = cursor
        
        chunk_size := MeasureTextLine(text[:cursor], s)

        // Automatic text wrapping
        if chunk_size.x >= box_size.x {
            // Single word wrapping
            if pcursor == 0 {
                x: f32
                p: int // previous i
                for r, i in text[:cursor] {
                    x += MeasureRune(r, s).x
                    if x >= box_size.x {
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
                text = text[pcursor:]
            }
            pcursor = 0
            cursor = 0
        }

        // New line characters
        if cursor < len(text) {
            // TODO is this even necessary?
            if text[cursor] == '\r' { // Windows: \r\n
                append(&lines, text[:cursor])
                text = text[cursor + 1:]
                pcursor = 0
                cursor  = 0

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

    return
}

// Slow, but very dynamic.
// Prefer caching, but don't get scared, it's probably fine.
DrawTextWrapped :: proc(text: string, pos: rl.Vector2, box_size: rl.Vector2, s: ^State, id: u64 = 0) -> (new_size: rl.Vector2) {
    opts := s.text_options
    original_text := text
    text  := text

    lines := SplitTextIntoLines(text, box_size, s)
    defer delete(lines)

    // --------------------- Drawing + selection --------------------- 

    is_mouse_start   := rl.IsMouseButtonPressed(.LEFT)
    is_mouse_ongoing := rl.IsMouseButtonDown(.LEFT)

    id := id if id != 0 || !opts.selectable else NextId(s)

    if sel_id == id && is_mouse_start {
        sel_id = 0
        sel_start, sel_end = 0, 0
        selection_in_progress = false
    }

    pos := pos
    rune_index: int
    // Drawing lines 
    for line, line_index in lines {
        defer rune_index += len(line)
        chunk_size := MeasureTextLine(line, s)
        
        o: rl.Vector2 // offset

        o.x = (box_size.x - chunk_size.x) / 2 if opts.center_x else 0
        o.y = (box_size.y - (opts.size + opts.line_spacing) * f32(len(lines))) / 2 + opts.size/2 if opts.center_y else 0
        o.y += f32(line_index) * ( opts.size + opts.line_spacing )

        // Drawing individual characters 
        for r, i in line {
            advance := MeasureRune(r, s)
            if advance == {} do continue

            //  Checking for mouse highlighting    ( this is all slow :< )
            a := pos + o
            b := advance
            if  opts.selectable && 
                rl.CheckCollisionPointRec(s.mouse, { pos.x, pos.y, box_size.x, box_size.y }) &&
                rl.CheckCollisionPointRec(s.mouse, { a.x, a.y, b.x, b.y }) {

                if is_mouse_start {
                    sel_id = id
                    sel_start = rune_index + i
                    selection_in_progress = true
                } else if is_mouse_ongoing && sel_id == id  {
                    sel_end = rune_index + i
                    selection = original_text[min(sel_start, sel_end):max(sel_start, sel_end)]
                    selection_in_progress = true
                }
            }

            // Background
            if sel_id == id &&
               rune_index + i >= min(sel_start, sel_end) && 
               rune_index + i <= max(sel_start, sel_end) {
                rl.DrawRectangleV(pos + o, advance, opts.highlight) 
            } else {
               rl.DrawRectangleV(pos + o, advance, opts.background) 
            }

            if r == '\t' do continue

            DrawRune(r, floor_vec(pos + o), s)
            o.x += advance.x
            new_size.x = max(new_size.x, o.x)
        }
    }

    new_size.y = f32(len(lines)) * ( opts.size + opts.line_spacing )

    if opts.selectable {
        pmouse := s.mouse - rl.GetMouseDelta()
        rec := rl.Rectangle { pos.x, pos.y, min(box_size.x, new_size.x), min(box_size.y, new_size.y) }
        a := rl.CheckCollisionPointRec(pmouse,  rec)
        b := rl.CheckCollisionPointRec(s.mouse, rec)
        if !a && b { rl.SetMouseCursor(.IBEAM) }
        if a && !b { rl.SetMouseCursor(.DEFAULT) }

        DebugDrawInfo(pos, box_size, id, s) 
    }

    return
}

LayoutText :: proc(text: string, size: rl.Vector2, allocator := context.allocator, s: ^State) -> (rune_positions: [] rl.Vector2, new_size: rl.Vector2) {
    opts := s.text_options

    lines := SplitTextIntoLines(text, size, s)
    defer delete(lines)

    rune_positions = make([] rl.Vector2, len(text))

    pos: rl.Vector2 
    rune_index: int
    // Drawing lines 
    for line, line_index in lines {
        defer rune_index += len(line)
        chunk_size := MeasureTextLine(line, s)
        
        o: rl.Vector2 // offset

        o.x = (size.x - chunk_size.x) / 2 if opts.center_x else 0
        o.y = (size.y - (opts.size + opts.line_spacing) * f32(len(lines))) / 2 + opts.size/2 if opts.center_y else 0
        o.y += f32(line_index) * ( opts.size + opts.line_spacing )

        // Drawing individual characters 
        for r, i in line {
            advance := MeasureRune(r, s)
            if advance == {} do continue

            rune_positions[rune_index + i] = floor_vec(pos + o)

            o.x += advance.x
            new_size.x = max(new_size.x, o.x)
        }
    }

    new_size.y = f32(len(lines)) * ( opts.size + opts.line_spacing )
    return
}


// 1. You should save the original contents of `text`!
//    to get text highlighting working. (Also don't forget to save the opts)
// 2. Either call DrawTextCached()
// 3. You may zero initialize the texture  (i.e. texture: rl.RenderTexture2D = {}).
CacheTextWrapped :: proc(texture: ^rl.RenderTexture2D, text: string, box_size: rl.Vector2, 
                         clear_color := rl.BLANK, s: ^State) -> (new_size: rl.Vector2) {

    if !rl.IsRenderTextureValid(texture^) {
        texture^ = rl.LoadRenderTexture(cast(i32) box_size.x + 2, cast(i32) box_size.y)
    }
    
    rl.BeginTextureMode(texture^)
    rl.ClearBackground(rl.BLANK)  // Remove this line to not reset the RenderTexture2D here
    new_size = DrawTextWrapped(text, { }, box_size, s)
    rl.EndTextureMode()

    return
}

// Generate the texture for this via CacheTextWrapped
// Pass the same text and the same options as to CacheTextWrapped
DrawTextCached :: proc(texture: rl.RenderTexture2D, pos: rl.Vector2, text := "", rune_positions: [] rl.Vector2 = {}, s: ^State, id: u64 = 0) {
    if s == nil { return }
    opts := s.text_options

    if len(text) != len(rune_positions) { panic("bad lengths") }

    tex := texture.texture
    box_size : rl.Vector2 = { f32(tex.width), f32(tex.height) }

    // Basically just copied from DrawTextWrapped. There for selection
    is_mouse_start   := rl.IsMouseButtonPressed(.LEFT)
    is_mouse_ongoing := rl.IsMouseButtonDown(.LEFT)
    
    id := id
    if opts.selectable { id = id if id != 0 || !opts.selectable else NextId(s) }

    if opts.selectable && (is_mouse_start || is_mouse_ongoing || sel_id != 0) {

        if sel_id == id && is_mouse_start {
            sel_id = 0
            sel_start, sel_end = 0, 0
            selection_in_progress = false
        }

        for rune_pos, i in rune_positions {
            advance := MeasureRune(rune((transmute([] byte) text)[i]), s)

            a := pos + rune_pos
            b := advance
            if  opts.selectable && 
                rl.CheckCollisionPointRec(s.mouse, { pos.x, pos.y, box_size.x, box_size.y }) &&
                rl.CheckCollisionPointRec(s.mouse, { a.x, a.y, b.x, b.y }) {

                if is_mouse_start {
                    sel_id = id
                    sel_start = i
                    selection_in_progress = true
                } else if is_mouse_ongoing {
                    if sel_id == id {
                        sel_end   = + i
                        selection = text[min(sel_start, sel_end):max(sel_start, sel_end)]
                        selection_in_progress = true
                    }
                }

                if sel_id == id && i >= min(sel_start, sel_end) && 
                                   i <= max(sel_start, sel_end) { 
                    rl.DrawRectangleV(pos + rune_pos, advance, opts.highlight) 
                }
            }
        
        }

        lines := SplitTextIntoLines(text, box_size, s)
        defer delete(lines)
    }

    rl.DrawTextureRec(tex, { 0, 0, f32(tex.width), - f32(tex.height) }, pos, rl.WHITE)

    if opts.selectable {
        pmouse := s.mouse - rl.GetMouseDelta()
        rec := rl.Rectangle { pos.x, pos.y, min(box_size.x, f32(tex.width)), min(box_size.y, f32(tex.height)) }
        a := rl.CheckCollisionPointRec(pmouse, rec)
        b := rl.CheckCollisionPointRec(s.mouse,  rec)
        if !a && b { rl.SetMouseCursor(.IBEAM) }
        if a && !b { rl.SetMouseCursor(.DEFAULT) }

        DebugDrawInfo(pos, box_size, id, s)
    }
}

/*
// Generate the texture for this via CacheTextWrapped
// Pass the same text and the same options as to CacheTextWrapped
DrawTextCached :: proc(texture: rl.RenderTexture2D, pos: rl.Vector2, original_text := "", original_state : ^State = nil, id: u64 = 0) {
    original_state := original_state if original_state != nil else &{ }
    opts := original_state.text_options
    s    := original_state

    tex := texture.texture
    text  := original_text
    box_size : rl.Vector2 = { f32(tex.width), f32(tex.height) }

    // Basically just copied from DrawTextWrapped. There for selection
    is_mouse_start   := rl.IsMouseButtonPressed(.LEFT)
    is_mouse_ongoing := rl.IsMouseButtonDown(.LEFT)
    
    // TODO REPLACE THIS ENTIRE THING WITH   rune_positions: [] rl.Vector2   and that's it!
    // Selecting text is slow af and it just does not matter
    if opts.selectable && (is_mouse_start || is_mouse_ongoing || sel_id != 0) {

        lines := SplitTextIntoLines(text, box_size, s)
        defer delete(lines)

        id := transmute(u64) pos

        if sel_id == id && is_mouse_start {
            sel_id = 0
            sel_start, sel_end = 0, 0
            selection_in_progress = false
        }

        pos := pos
        rune_index: int
        for line, line_index in lines {
            defer rune_index += len(line)
            chunk_size := MeasureTextLine(line, s)

            o: rl.Vector2 // offset

            o.x = (box_size.x - chunk_size.x) / 2 if opts.center_x else 0
            o.y = (box_size.y - (opts.size + opts.line_spacing) * f32(len(lines))) / 2 + opts.size/2 if opts.center_y else 0
            o.y += f32(line_index) * ( opts.size + opts.line_spacing )

            // Individual characters
            for r, i in line {
                advance := MeasureRune(r, original_state)
                if advance == {} do continue

                //  Checking for mouse highlighting
                a := pos + o
                b := advance
                if  opts.selectable && 
                    rl.CheckCollisionPointRec(s.mouse, { pos.x, pos.y, box_size.x, box_size.y }) &&
                    rl.CheckCollisionPointRec(s.mouse, { a.x, a.y, b.x, b.y }) {

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

                if sel_id == id &&
                   rune_index + i >= min(sel_start, sel_end) && 
                   rune_index + i <= max(sel_start, sel_end) {
                    rl.DrawRectangleV(pos + o, advance, opts.highlight) 
                }

                o.x += advance.x
            }
        }
    }

    rl.DrawTextureRec(tex, { 0, 0, f32(tex.width), - f32(tex.height) }, pos, rl.WHITE)

    if opts.selectable {
        pmouse := s.mouse - rl.GetMouseDelta()
        rec := rl.Rectangle { pos.x, pos.y, min(box_size.x, f32(tex.width)), min(box_size.y, f32(tex.height)) }
        a := rl.CheckCollisionPointRec(pmouse, rec)
        b := rl.CheckCollisionPointRec(s.mouse,  rec)
        if !a && b { rl.SetMouseCursor(.IBEAM) }
        if a && !b { rl.SetMouseCursor(.DEFAULT) }

        DebugDrawInfo(pos, box_size, id, original_state)
    }
}

*/


// These are probably correct, I didn't really check
// 0x024F = end of Latin Extended-B
// 0x7F   = end of ASCII
// for others: https://en.wikipedia.org/wiki/List_of_Unicode_characters
// SDF allows for better scaling of the font when compared to default(rasterization)
LoadFontFromMemory :: proc(data: [] byte, text_size: int, SDF := false, glyph_count := 0x024F, filter := rl.TextureFilter.TRILINEAR) -> rl.Font {
    font: rl.Font

    font.baseSize = i32(text_size)
    font.glyphCount = 25000
    
    font.glyphs = rl.LoadFontData(transmute(rawptr) raw_data(data), i32(len(data)), 
                  font.baseSize, nil, font.glyphCount, .SDF if SDF else .DEFAULT);

    atlas := rl.GenImageFontAtlas(font.glyphs, &font.recs, font.glyphCount, font.baseSize, 4, 0);
    font.texture = rl.LoadTextureFromImage(atlas);
    rl.UnloadImage(atlas);

    rl.SetTextureFilter(font.texture, filter)
    
    return font
}



@(private="file")
// Text looks better when it is drawn aligned to the nearest pixel
floor_vec :: proc(pos: rl.Vector2) -> rl.Vector2 {
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
