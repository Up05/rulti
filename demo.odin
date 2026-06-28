package rulti

import rl "vendor:raylib"
import "core:math"
import "core:fmt"

@private
main_camera: rl.Camera2D = { zoom = 1 }

@private
main :: proc() {

    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags({ .WINDOW_RESIZABLE, .MSAA_4X_HINT })

    rl.InitWindow(1280, 720, "rulti demo")
    rl.SetTargetFPS(30)
    
    font := LoadFontFromMemory(#load("font.ttf"), 24, false, 1007)
    font_math  := LoadFontFromMemory(#load("math.ttf"),  24, false)
    font_emoji := LoadFontFromMemory(#load("emoji.ttf"), 24, false)

    rl.SetTextureFilter(font.texture,       .BILINEAR)
    rl.SetTextureFilter(font_math.texture,  .BILINEAR)
    rl.SetTextureFilter(font_emoji.texture, .BILINEAR)

    state := &State {
        text_options = DEFAULT_TEXT_OPTIONS,
        ui_options   = DEFAULT_UI_OPTIONS,
    }

    { opts := &state.text_options
        opts.fallback_fonts = { font_math, font_emoji, rl.GetFontDefault() }
        opts.font    = font
        opts.size    = 24
        opts.spacing = 2
    }

    big_text: rl.RenderTexture2D
    new_size := CacheTextWrapped(&big_text, LOREM, { 600, 850 }, {}, state)
    scroll: Scroll = { max = new_size }

    state.debug = true

    ti: TextInput
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground({ 225, 225, 255, 255 })

        NewFrame(state, mouse = rl.GetScreenToWorld2D(rl.GetMousePosition(), main_camera))
        rl.BeginMode2D(main_camera);

        // s: time.Stopwatch
        // time.stopwatch_start(&s)
        // for y in 0..<100 {
        //     DrawTextBasic("123456712345671234567123456712345671234567123456712345671234567123456712345671234567123456712345671234567123456712345671234567", { 10, 10 + f32(y * 15) })
        // }
        // time.stopwatch_stop(&s)
        // fmt.println(time.stopwatch_duration(s))

        DrawTextBasic("λ(ℕ)", 0, state)
        glyph := rl.GetGlyphIndex(font, 'λ')

        state.text_options.selectable = true
        ti.placeholder = "a text input"
        DrawTextInput(&ti, { 20, 700 }, { 500, 26 }, state)


        // big, scrollable, block of text
        rl.DrawRectangleLinesEx({ 20, 20, 600, 650 }, 2, rl.BLACK)
        rl.BeginScissorMode(20 - i32(main_camera.target.x), 20 - i32(main_camera.target.y), 600, 650)
        DrawTextCached(big_text, { 20, 20 } - scroll.pos, LOREM, state)
        rl.EndScissorMode()
        DrawScrollbar(&scroll, { 20, 20 }, { 600, 650 }, state)

        // bottom left text
        size_x: f32 = 150
        size_x = math.abs(math.sin_f32(f32(rl.GetTime() / 2)) * 300)
        rl.DrawRectangleLinesEx(                     { 130, 760,     size_x, 240 }, 2, rl.BLACK)
        DrawTextWrapped("Abcd_efgh_ijkl_mnop rstu",  { 130, 760 }, { size_x, 240 }, With(state, background = rl.ORANGE))

        // bottom right text
        DrawTextWrapped("Abcd_efgh\n_ijkl_mnop rstu", { 430, 760 }, { size_x, 240 }, With(state, center_x = true))

        // off-screen capsules/"stadiums" (drag screen with mouse to move)
        DrawCapsule2D({100, -100}, {100, -300}, 50, 16, rl.RED)
        DrawCapsule2D({300, -100}, {450, -300}, 50, 16, rl.BLUE)

        if !selection_in_progress && !IsAnyScrollbarDragged() && rl.IsMouseButtonDown(.LEFT) { 
            main_camera.target -= rl.GetMouseDelta()
        }
        rl.EndMode2D()

        DrawTextBasic(fmt.aprintf("Frame time: %.6f", rl.GetFrameTime()), { 20, f32(rl.GetScreenHeight()) - state.text_options.size - 4 }, state)

        free_all(context.temp_allocator)

    }

}

LOREM :: `
Ar katės lizde. Mauris skurdo plano pagalvė. Ežere nėra neapykantos, rutrumas – prakeiksmas, jaunystė – prakeiksmas, jaunystė – prakeikimas. Tai visada malonumas ir palaima. Enėjas liūdi tik neapykantos didžiausiems taikiniams. Nelengva užduotis.

Dėl minkštų ir minkštų, ir malonių, malonių. Kartais namuose, net gyvenimo partneriai. Kiekvienos mielės nėra nei grynos, nei baltyminės. Jokio sijono, išskyrus lorem, o mielių katinas liūdnas nei. Kai kurie gali būti laisvi arba neturi ribų. Pellentesque ultrices cursus ex, quiver hendrerit lorem commodo, niekur kitur nepriskirtas. Rytoj nešiko draugai užsiėmę.

Ar katės lizde. Mauris skurdo plano pagalvė. Ežere nėra neapykantos, rutrumas – prakeiksmas, jaunystė – prakeiksmas, jaunystė – prakeikimas. Tai visada malonumas ir palaima. Enėjas liūdi tik neapykantos didžiausiems taikiniams. Nelengva užduotis.

Dėl minkštų ir minkštų, ir malonių, malonių. Kartais namuose, net gyvenimo partneriai. Kiekvienos mielės nėra nei grynos, nei baltyminės. Jokio sijono, išskyrus lorem, o mielių katinas liūdnas nei. Kai kurie gali būti laisvi arba neturi ribų. Pellentesque ultrices cursus ex, quiver hendrerit lorem commodo, niekur kitur nepriskirtas. Rytoj nešiko draugai užsiėmę.

Ar katės lizde. Mauris skurdo plano pagalvė. Ežere nėra neapykantos, rutrumas – prakeiksmas, jaunystė – prakeiksmas, jaunystė – prakeikimas. Tai visada malonumas ir palaima. Enėjas liūdi tik neapykantos didžiausiems taikiniams. Nelengva užduotis. Dėl minkštų ir minkštų, ir malonių, malonių. Kartais namuose, net gyvenimo partneriai. Kiekvienos mielės nėra nei grynos, nei baltyminės. Jokio sijono, išskyrus lorem, o mielių katinas liūdnas nei. Kai kurie gali būti laisvi arba neturi ribų. Pellentesque ultrices cursus ex, quiver hendrerit lorem commodo, niekur kitur nepriskirtas. Rytoj nešiko draugai užsiėmę.
`
