# Raylib addons

My collection of addons to Raylib written in odin-lang.
Files are mostly independent and may be deleted, HOWEVER
2 functions in the UI module depend on the Text module.

# Text module

Additions:
1. Text wrapping and caching for wrapped text
2. Support for the Odin's `string` type, to get fewer string copies.
3. A jumping-off point for mouse selection.
4. Compile time loading of fonts + simpler loading of SDF fonts.

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
DEFAULT_TEXT_OPTIONS  : TextOptions     // may be changed
selection             : string          // very volatile, stores user's selection text
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

# Shape modules

Additions:
1. Draw Rotated capsule using 2 points

## Functions

```odin

// Draws a 2D capsule (stadium). The points are a radius away from the highest/lowest point.
DrawCapsule2D :: proc(p1, p2: rl.Vector2, radius: f32, segments : int, color: rl.Color)

```

## UI module

**DrawTextInput & UpdateTextInput depends on the Text module!**

Additions:
1. Scrollbar
2. The Gruvbox colorscheme values (I just want them somewhere, okay!?)
3. Inset and outset borders
4. Text input (inspired by Firefox's URL bar)

## Functions

```odin

// Convert: 0xRRGGBBAA to raylib.Color
// do not forget to speficy alpha! zero is zero.
ColorFromHex :: proc(hex: u32) -> rl.Color

// The Scroll struct technically has 2 scrollbars: vertical & horizontal
// specify `horizontal = true`, and only the horizontal scrollbar will be checked...
IsScrollbarDragged :: proc(scroll: Scroll, horizontal: bool) -> bool
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
DrawScrollbar :: proc(scroll: ^Scroll, pos: rl.Vector2, size: rl.Vector2, opts := DEFAULT_UI_OPTIONS) 

// You may call this manually (every frame), if you want only 
// mouse/... scrolling but for scrollbars themselves to be hidden
UpdateScrollbar :: proc(scroll: ^Scroll, pos: rl.Vector2, size: rl.Vector2, opts := DEFAULT_UI_OPTIONS)

// 🭽▔▌ Draws a two color border, where bottom-right sides are brighter
// 🬂🬂🬀 this makes the rectangle look like it is embedded into ...
DrawBorderInset :: proc(pos, size: rl.Vector2, darker, brighter: rl.Color, thicker := false)

// 🬞🬭🬭 Draws a two color border, where top-left sides are brighter
// 🮉▁🭿 this makes the rectangle look like it pops out of ...
DrawBorderOutset :: proc(pos, size: rl.Vector2, darker, brighter: rl.Color, thicker := false)

// Just call this like a RectangleV... And (if using) give it your Camera2D
// Input is "stateful", so be careful not to recreate it each frame
// Scissoring is done automatically in this case
DrawTextInput :: proc(input: ^TextInput, pos, size: rl.Vector2, 
                      opts := DEFAULT_UI_OPTIONS, text_opts := DEFAULT_TEXT_OPTIONS)

// Called automatically, but can still be called by user when the input is actually hidden
UpdateTextInput :: proc(input: ^TextInput, pos, size: rl.Vector2, 
                        opts := DEFAULT_UI_OPTIONS, text_opts := DEFAULT_TEXT_OPTIONS)
```

## Public variables

```odin

DEFAULT_UI_OPTIONS : UIOptions

// Valid colors:
// 
//  FG0, FG1, FG2, FG3, FG4,
//  BG0, BG1, BG2, BG3, BG4,
//  BG0_HARD, BG0_SOFT,
//
//  RED1,    RED2,      GREEN1,  GREEN2,
//  YELLOW1, YELLOW2,   BLUE1,   BLUE2,
//  PURPLE1, PURPLE2,   AQUA1,   AQUA2,
//  GRAY1,   GRAY2,     ORANGE1, ORANGE2

gruvbox: [GruvboxPalette] raylib.Color
```

## Structs

```odin

UIOptions :: struct {
    camera : ^rl.Camera2D,         // to check if mouse is inside scrollable area and if the thumb is grabbed
    scroll : struct {
        width          : f32,      // vertical scrollbar's width and horizontal scrollbar's height
        track_bg       : rl.Color, // I prefer this to be darker
        thumb_bg       : rl.Color, //      and this to be brighter
        corner_bg      : rl.Color, // when both vertical and horizontal bars are visible
        border_dark    : rl.Color, // track has an inset border
        border_bright  : rl.Color, // thumb has an outset border
        speed_maintain : f32,      // percent of velocity to be leftover each frame
        speed          : f32,      // amount of velocity added (kind of, in pixels)
    }
}

Scroll :: struct {
    pos : rl.Vector2, // should be considered each frame in: my_pos -= scroll.pos
    max : rl.Vector2, // should be set to size of the entire scrollable thing
    vel : rl.Vector2, // private-ish
    id  : u64,        // private-ish
}

TextInput :: struct {
    text   : [dynamic] u8,  // for a custom allocator: make() the array yourself
    cursor : int,           // min(cursor, select) is the selection start
    select : int,           // max(cursor, select) is the right hand side of selection
    active : bool,          // just is the input active, could be set by user
    events : bit_set [TextInputEvent], // options are: { SUBMIT, ESCAPE, CHANGE }
    
    placeholder : string, // the text shown when text box is empty

    rune_positions : [dynamic] f32, // private, (pixel offsets by bytes + ..[0] = 0 after UpdateTextInput() )
    cursor_timeout : int,   // private, cursor timeout in frames
    cursor_visible : bool,  // private, cusror is the (custom) IBEAM thingy
}
``` 


