package rulti

import rl "vendor:raylib"
import "core:math"

vec :: rl.Vector2

LOREM :: `
Lorem ipsum dolor sit amet, consectetur adipiscing elit. In ultricies, quam quis viverra pharetra, lacus ligula imperdiet velit, sed cursus arcu justo non mi. Mauris elementum, nibh commodo tempus auctor, ante lectus finibus enim, et elementum eros ligula sed est. Duis mollis, dui vel pharetra dapibus, nisi tellus aliquam libero, non 

In vel felis lacus. Mauris egestas congue pulvinar. Nulla odio lacus, rutrum egestas nibh venenatis, eleifend varius ante. Praesent semper a lorem et fringilla. Aenean tristique nulla at odio maximus iaculis. Nulla facil.

Mauris vel mollis enim, et placerat orci. In congue interdum neque vitae sodales. Quisque fermentum nec purus nec dapibus. Nullam lacinia nisi lorem, et fermentum felis tristique nec. Aliquam ut rhoncus nibh, vel finibus nulla. Pellentesque ultrices cursus ex, pharetra hendrerit lorem commodo nec. Cras porttitor sodales molestie. 
`

main_camera: rl.Camera2D = { zoom = 1 }

main :: proc() {

    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags({ .WINDOW_RESIZABLE, .MSAA_4X_HINT })

    rl.InitWindow(1280, 720, "UML Generatorius")
    rl.SetTargetFPS(60)

    font := rl.LoadFontEx("Helvetica.ttf", 24, nil, 0x1FFF)
    rl.SetTextureFilter(font.texture, .TRILINEAR)

    DEFAULT_TEXT_OPTIONS.font = font

    DEFAULT_TEXT_OPTIONS.camera = &main_camera

    for !rl.WindowShouldClose() {
        rl.BeginDrawing() 
        defer rl.EndDrawing()
        rl.ClearBackground(rl.WHITE)
        
        // size: vec
        // size = MeasureTextLine("Test test test\ttest tets", 200)
        // rl.DrawLineV({ 200, 200 }, { 200, 200 } + size, rl.ORANGE)
        // DrawTextLine("Test test test\ttest tets", { 200, 200 })

        // size = MeasureTextLine("Test test test\ttest tets", 180)
        // rl.DrawLineV({ 180, 240 }, { 180, 240 } + size, rl.ORANGE)
        // DrawTextLine("Test test test\ttest tets", { 180, 240 })

        // DrawTextLine("Test test test\ttest tets", { 160, 280 })
        // DrawTextLine("Test test test\ttest tets", { 140, 320 })

        rl.BeginMode2D(main_camera); defer rl.EndMode2D()

        rl.DrawRectangleLinesEx({ 20, 20,     500, 650 }, 2, rl.BLACK)
        DrawTextWrapped(LOREM,  { 20, 20 }, { 500, 650 })



        DEFAULT_TEXT_OPTIONS.background = rl.ORANGE
        size_x: f32 = 150
        size_x = math.abs(math.sin_f32(f32(rl.GetTime() / 2)) * 300)
        rl.DrawRectangleLinesEx(                     { 130, 760,    size_x, 240 }, 2, rl.BLACK)
        DrawTextWrapped("Abcd_efgh_ijkl_mnop rstu",  { 130, 760 }, { size_x, 240 })
    
        DEFAULT_TEXT_OPTIONS.background = {}
        DrawTextWrapped("Abcd_efgh\n_ijkl_mnop rstu", { 430, 760 }, { size_x, 240 })

        if !selection_in_progress && rl.IsMouseButtonDown(.LEFT) do main_camera.target -= rl.GetMouseDelta()

    }

}
