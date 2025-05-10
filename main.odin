package rulti

import rl "vendor:raylib"
import "core:math"
import "core:fmt"

vec :: rl.Vector2

// LOREM :: `
// Lorem ipsum dolor sit amet, consectetur adipiscing elit. In ultricies, quam quis viverra pharetra, lacus ligula imperdiet velit, sed cursus arcu justo non mi. Mauris elementum, nibh commodo tempus auctor, ante lectus finibus enim, et elementum eros ligula sed est. Duis mollis, dui vel pharetra dapibus, nisi tellus aliquam libero, non 
// 
// In vel felis lacus. Mauris egestas congue pulvinar. Nulla odio lacus, rutrum egestas nibh venenatis, eleifend varius ante. Praesent semper a lorem et fringilla. Aenean tristique nulla at odio maximus iaculis. Nulla facil.
// 
// Mauris vel mollis enim, et placerat orci. In congue interdum neque vitae sodales. Quisque fermentum nec purus nec dapibus. Nullam lacinia nisi lorem, et fermentum felis tristique nec. Aliquam ut rhoncus nibh, vel finibus nulla. Pellentesque ultrices cursus ex, pharetra hendrerit lorem commodo nec. Cras porttitor sodales molestie. 
// `

LOREM :: `
Ar katės lizde. Mauris skurdo plano pagalvė. Ežere nėra neapykantos, rutrumas – prakeiksmas, jaunystė – prakeiksmas, jaunystė – prakeikimas. Tai visada malonumas ir palaima. Enėjas liūdi tik neapykantos didžiausiems taikiniams. Nelengva užduotis.

Dėl minkštų ir minkštų, ir malonių, malonių. Kartais namuose, net gyvenimo partneriai. Kiekvienos mielės nėra nei grynos, nei baltyminės. Jokio sijono, išskyrus lorem, o mielių katinas liūdnas nei. Kai kurie gali būti laisvi arba neturi ribų. Pellentesque ultrices cursus ex, quiver hendrerit lorem commodo, niekur kitur nepriskirtas. Rytoj nešiko draugai užsiėmę.
`




main_camera: rl.Camera2D = { zoom = 1 }

main :: proc() {

    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags({ .WINDOW_RESIZABLE, .MSAA_4X_HINT })

    rl.InitWindow(1280, 720, "UML Generatorius")
    // rl.SetTargetFPS(60)

    // font := rl.LoadFontEx("Helvetica.ttf", 24, nil, 0x1FFF)
    font := LoadFontFromMemory(#load("Helvetica.ttf"), 24, false)
    rl.SetTextureFilter(font.texture, .TRILINEAR)

    DEFAULT_TEXT_OPTIONS.font = font
    DEFAULT_TEXT_OPTIONS.selectable = true

    DEFAULT_TEXT_OPTIONS.camera = &main_camera

    big_text: rl.RenderTexture2D
    
    CacheTextWrapped(&big_text, LOREM, 20, { 600, 400 })

    angle: f32

    for a in Direction {
        for b in Direction { 
            A := int(a)
            B := int(b)
            fmt.print("---", a, "\t", b, "   \t")

            if math.abs(A - B) % 2 == 1 do fmt.println("L")
            if math.abs(A - B)     == 2 do fmt.println("><")
            if                   a == b do fmt.println("<>")
        }
    }

    for !rl.WindowShouldClose() {
        rl.BeginDrawing() 
        defer rl.EndDrawing()
        rl.ClearBackground(rl.WHITE)

        rl.BeginMode2D(main_camera); 

        mouse := rl.GetScreenToWorld2D(rl.GetMousePosition(), main_camera)

        // Arrows
        
        rl.DrawLine(400, 600, 800, 600, rl.YELLOW)
        rl.DrawLine(600, 400, 600, 800, rl.YELLOW)
        DrawZagArrow({ 600, 600 }, mouse, .LEFT, .LEFT)

        // Angles

        rl.DrawLineV({500, 500}, { 500 + math.cos(angle)*50, 500 + math.sin(angle)*50 }, rl.BLACK)
        switch AngleToDir(angle) {
        case .RIGHT: rl.DrawLine(500, 500, 550, 500, rl.BLACK)
        case .UP:    rl.DrawLine(500, 500, 500, 450, rl.BLACK)
        case .LEFT:  rl.DrawLine(500, 500, 450, 500, rl.BLACK)
        case .DOWN:  rl.DrawLine(500, 500, 500, 550, rl.BLACK)
        }
        angle += 0.001

        // Text At the top

        rl.DrawRectangleLinesEx({ 20, 20,     600, 400 }, 2, rl.BLACK)
        // DrawTextWrapped(LOREM,  { 20, 20 }, { 600, 650 })
        DrawTextCached(big_text, {20, 20}, LOREM)

        // Text at the bottom

        DEFAULT_TEXT_OPTIONS.background = rl.ORANGE
        size_x: f32 = 150
        size_x = math.abs(math.sin_f32(f32(rl.GetTime() / 2)) * 300)
        rl.DrawRectangleLinesEx(                     { 130, 760,    size_x, 240 }, 2, rl.BLACK)
        DrawTextWrapped("Abcd_efgh_ijkl_mnop rstu",  { 130, 760 }, { size_x, 240 })

        DEFAULT_TEXT_OPTIONS.background = {}
        DrawTextWrapped("Abcd_efgh\n_ijkl_mnop rstu", { 430, 760 }, { size_x, 240 })

        if !selection_in_progress && rl.IsMouseButtonDown(.LEFT) do main_camera.target -= rl.GetMouseDelta()

        rl.EndMode2D()
        
        DEFAULT_TEXT_OPTIONS.camera = nil
        DrawTextBasic(fmt.aprintf("Frame time: %.6f", rl.GetFrameTime()), { 20, f32(rl.GetScreenHeight()) - DEFAULT_TEXT_OPTIONS.size })
        


    }

}
