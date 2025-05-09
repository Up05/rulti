# Raylib addons

This is a single-file library for Raylib written in odin-lang adding.

It will (might) have a bunch of little things I find useful.

Currently there is only text wrapping and text draw/measure functions that take in `rune` and `string`

# Text

## Functions

```odin
// Draws a single line of text. (NOT YET DONE, IGNORES HIGHLIGHTING, BACKGROUND AND CENTERING)
DrawTextBasic :: proc(text: string, pos: rl.Vector2, opts := DEFAULT_TEXT_OPTIONS) 

// Draws the wrapped text
DrawTextWrapped :: proc(text: string, pos: rl.Vector2, box_size: rl.Vector2, 
                        opts := DEFAULT_TEXT_OPTIONS) -> (new_size: vec, ok: bool)

// Draws text to a texture for later use.
// If you will allow selecting text, then save the original text's contents and options.
CacheTextWrapped :: proc( texture: ^rl.RenderTexture2D, text: string, pos_x_for_tab: f32, box_size: rl.Vector2, 
                          clear_color := rl.BLANK, opts := DEFAULT_TEXT_OPTIONS) -> (new_size: vec)

// Draws the texture, (maybe) created by CacheTextWrapped
// Also allows for text selection
DrawTextCached :: proc( texture: rl.RenderTexture2D, pos: vec,
                        original_text := "", original_opts := DEFAULT_TEXT_OPTIONS )


// Use with #load("path/to/file.ttf") 
LoadFontFromMemory :: proc(data: [] byte, text_size: int, SDF := false, glyph_count := 0x024F) -> rl.Font 


// Gets the to-be size of the rune (position does not matter unless it's a '\t')
MeasureRune :: proc(r: rune, pos: rl.Vector2 = {}, opts := DEFAULT_TEXT_OPTIONS) -> (advance: rl.Vector2) 

// Same deal, ignore x_pos_for_tab if text does not contain '\t'
MeasureTextLine :: proc(text: string, x_pos_for_tab : f32 = 0, opts := DEFAULT_TEXT_OPTIONS) -> (text_size: vec) 
```

## Public Variables

```odin
DEFAULT_TEXT_OPTIONS  : TextOptions     // May be changed
selection             : string          // Very volatile, stores user's selection text
selection_in_progress : bool            // whether a text selection currently exists
```

## Structs

```odin
TextOptions :: struct {
    font         : rl.Font,
    size         : f32,
    spacing      : f32,
    line_spacing : f32,         
    tab_width    : f32,          // tab shift character max width
    force_left   : f32,          // somewhat internal, forces everything left, except tabstops

    center_x     : bool,         // whether to center horizontally
    center_y     : bool,         // whether to center  verticallly
    selectable   : bool,         // whether text is selectable with the mouse

    color        : rl.Color,     // the text character color
    background   : rl.Color,     // tightly wrapped
    highlight    : rl.Color,     // text selection color

    camera       : ^rl.Camera2D, // set this if selectable = true and text is drawn in BeginMode2D(...)
}
```
