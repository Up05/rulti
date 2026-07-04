#+feature using-stmt
package rulti

import rl "vendor:raylib"
import "core:unicode"
import "core:strings"
import "core:fmt"

TextOptions :: struct {
    fallback_fonts : [dynamic; #config(RULTI_MAX_FALLBACK_FONTS, 8)] rl.Font,
    font           : rl.Font,
    size           : f32,
    spacing        : f32,
    line_spacing   : f32,         

    center_x       : bool,         // whether to center horizontally
    center_y       : bool,         // whether to center  verticallly

    color          : rl.Color,     // the text character color
    background     : rl.Color,     // tightly wrapped
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
}

// 0x7F   = end of ASCII
// 0x024F = end of Latin Extended-B
// SDF allows for better scaling of the font when compared to default(rasterization)
// Do not use Raylib with system fonts! Vendor your fonts!
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
    advance_x := f32(font.glyphs[glyph].advanceX)
    if advance_x == 0 { advance_x = font.recs[glyph].width }

    advance.x += advance_x * scaling + opts.spacing
    advance.y  = opts.size + opts.line_spacing

    return
}

// y component is a line + it's advance even if given an empty string
// x component may be zero
// '\n' are ignored.
MeasureTextLine :: proc(text: string, s: ^State) -> (text_size: rl.Vector2) {
    opts := s.text_options
    #no_bounds_check for r, i in text { text_size += MeasureRune(r, s) }
    text_size.y = opts.size + opts.line_spacing // not unnecessary.
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
DrawTextBasic :: proc(text: string, pos: rl.Vector2, s: ^State) -> (text_size: rl.Vector2) {
    opts := s.text_options
        
    offset: rl.Vector2
    for r, i in text {
        if r < ' ' do continue

        rl.DrawRectangleV(pos + offset, MeasureRune(r, s), opts.background)
        DrawRune(r, pos + offset, s)
                
        advance  := MeasureRune(r, s).x
        offset.x += advance
    }
    
    return { offset.x, opts.size + opts.line_spacing }
}

// Slow, but very dynamic.
// Prefer caching, but don't get scared, it's probably fine.
DrawTextWrapped :: proc(text: string, pos: rl.Vector2, box_size: rl.Vector2, s: ^State) -> (new_size: rl.Vector2) {
    opts := s.text_options
    original_text := text
    text  := text

    // lines := SplitTextIntoLines(text, box_size, s)
    // defer delete(lines)
    fmt.println()

    // Drawing lines 
    text_iterator := text
    rune_index    : int
    line_index    : int
    for line in IterateNextVisualLine(&text_iterator, box_size.x, s) {
        // I should skip the non-printable characters right here?
        // but then... I shouldn't skip punctuation here (maybe that's fine)
        fmt.println(line)
        defer line_index += 1
        defer rune_index += len(line)
        chunk_size := MeasureTextLine(line, s)
        
        o: rl.Vector2 // offset

        if opts.center_x { o.x = (box_size.x - chunk_size.x) / 2 }             //   \/ len(lines) ???
        if opts.center_y { o.y = (box_size.y - (opts.size + opts.line_spacing) * f32(1)) / 2 + opts.size/2 }
        o.y += f32(line_index) * ( opts.size + opts.line_spacing )

        // Drawing individual characters 
        for r, i in line {
            advance := MeasureRune(r, s)
            if advance == {} do continue

            rl.DrawRectangleV(pos + o, advance, opts.background) 
               DrawRune(r, floor_vec(pos + o), s)

            o.x += advance.x
            new_size.x = max(new_size.x, o.x)
        }
    }

    new_size.y = f32(line_index) * ( opts.size + opts.line_spacing )

    return
}

DrawTextWithLayout :: proc(text: string, rune_positions: [] rl.Vector2, pos: rl.Vector2, s: ^State) {
    for r, i in text {
        if i >= len(rune_positions) { return }
        if r < ' ' { continue } 
        DrawRune(r, pos + rune_positions[i], s)
    }
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
// state does nothing here
DrawTextCached :: proc(texture: rl.RenderTexture2D, pos: rl.Vector2, s: ^State = nil) {
    tex := texture.texture
    rl.DrawTextureRec(tex, { 0, 0, f32(tex.width), - f32(tex.height) }, pos, rl.WHITE)
}

IterateNextVisualLine :: proc(text: ^string, width: f32, s: ^State) -> (line: string, ok: bool) {
    opts := s.text_options

    if len(text) == 0 { return "", false }
    
    x: f32
    for r, i in text {
        x += MeasureRune(r, s).x

        if r == '\n' {
            line  = text[:i]
            text^ = text[i:]
            return line, len(line) > 0
        }

        // :(
        for iterate_punctuation {
        
        
        }

        // prefer split on spaces && punctuation
        if unicode.is_punct(r) /* || unicode.is_space(r) */ {
            next_punct  := find_next_punct_from(text^, i + 1)
            next_chunk  := text[i + 1:next_punct]
            chunk_width := MeasureTextLine(next_chunk, s).x if next_punct < len(text^) else 0

            if x + chunk_width >= width {
                fmt.println("!", next_chunk)
                line  = text[i:]
                text^ = text[:i]
                return line, len(line) > 0
            }
        }

        // split individual characters
        if x >= width {
            line  = text[:i]
            text^ = text[i:]
            return line, len(line) > 0
        }
    }

    line  = text^
    text^ = text[len(text):]
    return line, len(line) > 0

    find_next_punct_from :: proc(str: string, offset: int) -> int {
        if offset >= len(str) do return len(str)

        one_basic: bool // does this shit work?
        for r, i in str[offset:] {
            if !unicode.is_punct(r)  { one_basic = true; fmt.println("not punct:", r);  }
            if  unicode.is_punct(r) && one_basic { return i + offset }
        }
        return len(str)
    }
}

// Less useful for user. Wraps text into new lines.
SplitTextIntoLines :: proc(text: string, box_size: rl.Vector2, s: ^State, allocator := context.allocator) -> (lines: [dynamic] string) {
    opts := s.text_options
    text := text
    lines = make([dynamic] string, 0, int(f32(len(text)) / (box_size.x / MeasureRune(' ', s).x)) + 4, allocator)
    // defer fmt.println(lines)

    cursor      : int
    pcursor     : int // previous cursor

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
                        append(&lines, strings.trim_left_space(text[p:i])) // <-- this is bad because it doesn't preserve runes
                        p = i + 1
                        x = 0
                    }
                }
            
                append(&lines, text[p:cursor])
                text = text[cursor:]
            } else {
                // Wrapping over non-printable characters & space
                append(&lines, strings.trim_left_space(text[:pcursor]))
                text = text[pcursor:]
            }
            pcursor = 0
            cursor = 0
        }

        // New line characters
        if cursor < len(text) {
            if text[cursor] == '\n' { // Else: \n
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

// Calculates the position of every rune in a wrapped text
// This allows you to use DrawTextFromLayout, to implement text highlighting and more
LayoutText :: proc(text: string, size: rl.Vector2, allocator := context.allocator, s: ^State) -> (rune_positions: [] rl.Vector2, new_size: rl.Vector2) {
    opts := s.text_options

    lines := SplitTextIntoLines(text, size, s)
    defer delete(lines)

    rune_positions = make([] rl.Vector2, len(text))

    // Drawing lines 
    rune_index: int
    pos: rl.Vector2 
    for line, line_index in lines {
        defer rune_index += len(line)
        chunk_size := MeasureTextLine(line, s)
        
        o: rl.Vector2 // offset

        o.x = (size.x - chunk_size.x) / 2 if opts.center_x else 0
        o.y = (size.y - (opts.size + opts.line_spacing) * f32(len(lines))) / 2 + opts.size/2 if opts.center_y else 0
        o.y += f32(line_index) * ( opts.size + opts.line_spacing )

        // Drawing individual characters 
        for r, i in line {
            rune_positions[rune_index + i] = floor_vec(pos + o)
            new_size.x = max(new_size.x, o.x)
            o.x += MeasureRune(r, s).x
        }
    }
    new_size.y = f32(len(lines)) * ( opts.size + opts.line_spacing )
    return
}


@(private="file")
// Text looks better when it is drawn aligned to the nearest pixel
floor_vec :: proc(pos: rl.Vector2) -> rl.Vector2 {
    return { f32(i32(pos.x)), f32(i32(pos.y)) }
}

@(private="file")
find_space_from :: proc(str: string, offset: int) -> int {
    if offset >= len(str) do return len(str)

    one_non_space: bool
    for r, i in str[offset:] {
        if r >  ' '  { one_non_space = true }
        if r <= ' ' && one_non_space { return i + offset }
    }
    return len(str)
}

/*
    // id := id
    // if opts.selectable { id = id if id != 0 || !opts.selectable else NextId(s) }

    // if opts.selectable && (is_mouse_start || is_mouse_ongoing || sel_id != 0) {
    //
    //     if sel_id == id && is_mouse_start {
    //         sel_id = 0
    //         sel_start, sel_end = 0, 0
    //         selection_in_progress = false
    //     }
    //
    //     for rune_pos, i in rune_positions {
    //         advance := MeasureRune(rune((transmute([] byte) text)[i]), s)
    //
    //         a := pos + rune_pos
    //         b := advance
    //         if  opts.selectable && 
    //             rl.CheckCollisionPointRec(s.mouse, { pos.x, pos.y, box_size.x, box_size.y }) &&
    //             rl.CheckCollisionPointRec(s.mouse, { a.x, a.y, b.x, b.y }) {
    //
    //             if is_mouse_start {
    //                 sel_id = id
    //                 sel_start = i
    //                 selection_in_progress = true
    //             } else if is_mouse_ongoing {
    //                 if sel_id == id {
    //                     sel_end   = + i
    //                     selection = text[min(sel_start, sel_end):max(sel_start, sel_end)]
    //                     selection_in_progress = true
    //                 }
    //             }
    //         }
    //
    //         if sel_id == id && i >= min(sel_start, sel_end) && 
    //                             i <= max(sel_start, sel_end) { 
    //             rl.DrawRectangleV(pos + rune_pos, advance, opts.highlight) 
    //         }
    //     
    //     }
    // 
    //     lines := SplitTextIntoLines(text, box_size, s)
    //     defer delete(lines)
    // }

    // if opts.selectable {
    //     pmouse := s.mouse - rl.GetMouseDelta()
    //     rec := rl.Rectangle { pos.x, pos.y, min(box_size.x, f32(tex.width)), min(box_size.y, f32(tex.height)) }
    //     a := rl.CheckCollisionPointRec(pmouse, rec)
    //     b := rl.CheckCollisionPointRec(s.mouse,  rec)
    //     if !a && b { rl.SetMouseCursor(.IBEAM) }
    //     if a && !b { rl.SetMouseCursor(.DEFAULT) }
    //   
    //     DebugDrawInfo(pos, box_size, id, s)
    // }
*/

