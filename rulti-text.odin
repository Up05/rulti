package rulti

import rl "vendor:raylib"
import "core:fmt"

vec :: rl.Vector2

TextOptions :: struct {
    font         : rl.Font,
    size         : f32,
    spacing      : f32,
    line_spacing : f32,         
    tab_width    : f32,         // tab shift character max width
    force_left   : f32,         // somewhat internal, forces everything left, except tabstops

    center_x     : bool,        // whether to center horizontally
    center_y     : bool,        // whether to center  verticallly
    selectable   : bool,        // whether text is selectable with the mouse

    color        : rl.Color,    // the text character color
    background   : rl.Color,    // tightly wrapped
    highlight    : rl.Color,    // text selection color

    camera       : ^rl.Camera2D,// set this if selectable = true and text is drawn after `BeginMode2D(...)`...
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

// These are much more volatile
@(private) sel_start : int 
@(private) sel_end   : int // btw, sel_end can be less than sel_start 
@(private) sel_id    : u64

// Returns the size of a rune accounted for TextOptions.
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

// don't worry about x_pos_for_tab too much, especially for centered text
// because I just do not believe that a text that is centered should ever contain tabs. 
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

// Draws a single line text. No centering, selection or '\n' handling.
DrawTextBasic :: proc(text: string, pos: rl.Vector2, opts := DEFAULT_TEXT_OPTIONS) -> (text_size: vec) {
    opts := opts
    using opts
    if font.texture.id == 0 do font = rl.GetFontDefault()
        
    // Selection
    is_mouse_start   := rl.IsMouseButtonPressed(.LEFT)
    is_mouse_ongoing := rl.IsMouseButtonDown(.LEFT)

    id := transmute(u64) pos

    if sel_id == id && is_mouse_start {
        sel_id = 0
        sel_start, sel_end = 0, 0
        selection_in_progress = false
    }
    cam: rl.Camera2D = camera^ if camera != nil else { zoom = 1 }
    mouse := rl.GetScreenToWorld2D(rl.GetMousePosition(), cam)

    scaling := size / f32(font.baseSize)
    offset: vec
    for r, i in text {
        if r < ' ' && r != '\t' do continue

        rl.DrawRectangleV(pos + offset, MeasureRune(r, pos + offset), background)
        rl.DrawTextCodepoint(font, r, pos + offset, size, color)
                
        glyph := rl.GetGlyphIndex(font, r)
        advance1 := f32(font.glyphs[glyph].advanceX)
        advance  := (advance1 if advance1 != 0 else font.recs[glyph].width) * scaling + spacing
        offset.x += advance
        if r == '\t' {
            offset.x += tab_width - f32(i32(pos.x + offset.x)%i32(tab_width))
        }

        //  Checking for mouse highlighting 
        ax := pos.x + offset.x - advance
        bx := advance
        if selectable && rl.CheckCollisionPointRec(mouse, { ax, pos.y, bx, opts.size }) {
            
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
    
    if selectable {
        pmouse := mouse - rl.GetMouseDelta()
        a := rl.CheckCollisionPointRec(pmouse, { pos.x, pos.y, offset.x, size + line_spacing })
        b := rl.CheckCollisionPointRec(mouse,  { pos.x, pos.y, offset.x, size + line_spacing })
        if !a && b { rl.SetMouseCursor(.IBEAM) }
        if a && !b { rl.SetMouseCursor(.DEFAULT) }
    }

    return { offset.x, size + line_spacing }
}

// Less useful for user. Wraps text into new lines.
SplitTextIntoLines :: proc(text: string, pos: rl.Vector2, box_size: rl.Vector2, 
                           opts := DEFAULT_TEXT_OPTIONS) -> (lines: [dynamic] string) {
    text := text
    lines = make([dynamic] string, context.allocator)
    cursor : int
    pcursor: int // previous cursor
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
                for r, i in text[:cursor] {
                    x += MeasureRune(r).x
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
            if text[cursor] == '\r' { // Windows: \r\n
                append(&lines, text[:cursor])
                text = text[cursor + 1:]
                pcursor = 0
                cursor  = 0

                // For ..<macOS 9 remove '+ 1' on line with 'text ='
                // uncomment this line:  (and hope)
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

    return
}

// Slow, generates thousands of draw calls for long text, but is very dynamic.
// Prefer caching, but don't get scared, it's probably fine.
DrawTextWrapped :: proc(text: string, pos: rl.Vector2, box_size: rl.Vector2, 
                        opts := DEFAULT_TEXT_OPTIONS) -> (new_size: vec) {
    using opts
    
    original_text := text
    text  := text

    lines := SplitTextIntoLines(text, pos, box_size, opts)
    defer delete(lines)

    // --------------------- Drawing + selection --------------------- 

    is_mouse_start   := rl.IsMouseButtonPressed(.LEFT)
    is_mouse_ongoing := rl.IsMouseButtonDown(.LEFT)

    id := transmute(u64) pos

    if sel_id == id && is_mouse_start {
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
            advance := MeasureRune(r, pos + o, opts)
            if advance == {} do continue

            //  Checking for mouse highlighting    ( this is all slow :< )
            a := pos + o
            b := advance
            if  selectable && 
                rl.CheckCollisionPointRec(mouse, { pos.x, pos.y, box_size.x, box_size.y }) &&
                rl.CheckCollisionPointRec(mouse, { a.x, a.y, b.x, b.y }) {

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

            shift : vec = { -force_left, 0 }

            // Background
            if sel_id == id &&
               rune_index + i >= min(sel_start, sel_end) && 
               rune_index + i <= max(sel_start, sel_end) {
                rl.DrawRectangleV(pos + o + shift, advance, highlight) 
            } else {
               rl.DrawRectangleV(pos + o + shift, advance, background) 
            }

            if r == '\t' do continue

            rl.DrawTextCodepoint(font, r, floor_vec(pos + o + shift), size, color)
            o.x += advance.x
            new_size.x = max(new_size.x, o.x)
        }
    }

    new_size.y = f32(len(lines)) * ( size + line_spacing )

    if selectable {
        pmouse := mouse - rl.GetMouseDelta()
        rec := rl.Rectangle { pos.x, pos.y, min(box_size.x, new_size.x), min(box_size.y, new_size.y) }
        a := rl.CheckCollisionPointRec(pmouse, rec)
        b := rl.CheckCollisionPointRec(mouse,  rec)
        if !a && b { rl.SetMouseCursor(.IBEAM) }
        if a && !b { rl.SetMouseCursor(.DEFAULT) }
    }


    return
}

// 1. You should save the original contents of `text`!
//    to get text highlighting working. (Also don't forget to save the opts)
// 2. Either call DrawTextCached()
// 3. You may zero initialize the texture  (i.e. texture: rl.RenderTexture2D = {}).
CacheTextWrapped :: proc( texture: ^rl.RenderTexture2D, text: string, pos_x_for_tab: f32, box_size: rl.Vector2, 
                          clear_color := rl.BLANK, opts := DEFAULT_TEXT_OPTIONS) -> (new_size: vec) {

    if !rl.IsRenderTextureValid(texture^) {
        texture^ = rl.LoadRenderTexture(cast(i32) box_size.x + 2, cast(i32) box_size.y)
    }
    
    rl.BeginTextureMode(texture^)
    rl.ClearBackground(rl.BLANK)  // Remove this line to not reset the RenderTexture2D here
    opts := opts
    opts.force_left = pos_x_for_tab
    new_size = DrawTextWrapped(text, { pos_x_for_tab, 0 }, box_size, opts)

    rl.EndTextureMode()
    return
}


// Generate the texture for this via CacheTextWrapped
// Pass the same text and the same options as to CacheTextWrapped
DrawTextCached :: proc( texture: rl.RenderTexture2D, pos: vec,
                        original_text := "", original_opts := DEFAULT_TEXT_OPTIONS ) {
    using original_opts

    tex := texture.texture
    text  := original_text
    box_size : vec = { f32(tex.width), f32(tex.height) }

    // Basically just copied from DrawTextWrapped. There for selection
    is_mouse_start   := rl.IsMouseButtonPressed(.LEFT)
    is_mouse_ongoing := rl.IsMouseButtonDown(.LEFT)

    cam: rl.Camera2D = camera^ if camera != nil else { zoom = 1 }
    mouse := rl.GetScreenToWorld2D(rl.GetMousePosition(), cam)
    
    // Selecting text is slow af and it just does not matter
    if is_mouse_start || is_mouse_ongoing || sel_id != 0 {

        lines := SplitTextIntoLines(text, pos, box_size, original_opts)
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
            chunk_size := MeasureTextLine(line, pos.x, original_opts)

            o: vec // offset

            o.x = (box_size.x - chunk_size.x) / 2 if center_x else 0
            o.y = (box_size.y - (size + line_spacing) * f32(len(lines))) / 2 + size/2 if center_y else 0
            o.y += f32(line_index) * ( size + line_spacing )

            // Individual characters
            for r, i in line {
                advance := MeasureRune(r, pos + o, original_opts)
                if advance == {} do continue

                //  Checking for mouse highlighting
                a := pos + o
                b := advance
                if  selectable && 
                    rl.CheckCollisionPointRec(mouse, { pos.x, pos.y, box_size.x, box_size.y }) &&
                    rl.CheckCollisionPointRec(mouse, { a.x, a.y, b.x, b.y }) {

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

                shift : vec = { -force_left, 0 }

                if sel_id == id &&
                   rune_index + i >= min(sel_start, sel_end) && 
                   rune_index + i <= max(sel_start, sel_end) {
                    rl.DrawRectangleV(pos + o + shift, advance, highlight) 
                }

                o.x += advance.x
            }
        }
    }

    rl.DrawTextureRec(tex, { 0, 0, f32(tex.width), - f32(tex.height) }, pos, rl.WHITE)

    if selectable {
        pmouse := mouse - rl.GetMouseDelta()
        rec := rl.Rectangle { pos.x, pos.y, min(box_size.x, f32(tex.width)), min(box_size.y, f32(tex.height)) }
        a := rl.CheckCollisionPointRec(pmouse, rec)
        b := rl.CheckCollisionPointRec(mouse,  rec)
        if !a && b { rl.SetMouseCursor(.IBEAM) }
        if a && !b { rl.SetMouseCursor(.DEFAULT) }
    }
}

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
