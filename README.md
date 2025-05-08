# Raylib addons

This is a single-file library for Raylib written in odin-lang adding.

It will (might) have a bunch of little things I find useful.

Currently there is only text wrapping and text draw/measure functions that take in `rune` and `string`

# Text

## Functions

```
// Gets the to-be size of the rune (position does not matter unless it's a '\t')
MeasureRune :: proc(r: rune, pos: rl.Vector2 = {}, opts := DEFAULT_TEXT_OPTIONS) -> (advance: rl.Vector2) 

// Draws a single line of text. (NOT YET DONE, IGNORES HIGHLIGHTING, BACKGROUND AND CENTERING)
DrawTextLine :: proc(text: string, pos: rl.Vector2, opts := DEFAULT_TEXT_OPTIONS) 

// Same deal, ignore x_pos_for_tab if text does not contain '\t'
MeasureTextLine :: proc(text: string, x_pos_for_tab : f32 = 0, opts := DEFAULT_TEXT_OPTIONS) -> (text_size: vec) 

// Draws the wrapped text, depends upon all options EXCEPT TextOptions.camera (STILL TODO)
DrawTextWrapped :: proc(text: string, pos: rl.Vector2, box_size: rl.Vector2, 
                        opts := DEFAULT_TEXT_OPTIONS) -> (new_size: vec, ok: bool) {

```

## Public Variables

```
DEFAULT_TEXT_OPTIONS:   TextOptions     // May be changed
selection:              stringa         // Very volatile, stores user's selection text
```
## Structs

```
TextOptions :: struct {
    font         : rl.Font,
    size         : f32,
    spacing      : f32,
    line_spacing : f32,         
    tab_width    : f32,          // tab shift character max width

    center_x     : bool,         // whether to center horizontally
    center_y     : bool,         // whether to center  verticallly
    selectable   : bool,         // whether text is selectable with the mouse

    color        : rl.Color,     // the text character color
    background   : rl.Color,     // tightly wrapped
    highlight    : rl.Color,     // text selection color

    camera       : ^rl.Camera2D, // set this if selectable = true and text is drawn in BeginMode2D(...)
}
```
