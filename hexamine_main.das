require daslib/media
require daslib/decs_boost
require hexes
require images
require simple_ui
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

let
    background_color = 0x333333
    digit_colors = [[auto 0x0000FF;
                          0x42CA42;
                          0xFF2018;
                          0x19A3DA;
                          0xC71DBD;
                          0xCFA227]]
    progress_for_life = 75

var
    selected_hex = int2(-1, -1)
    generated = false
    game_finished = false
    image_size = 1.0
    hexes_radius = 5
    num_mines = 20
    num_flags = 0
    is_in_game = false
    infinity = false
    extra_lifes = 0
    rounded_progress = 0
    progress = 0


def draw_image_alpha(img; pos)
    let image_pos = pos - 0.5 * float2(image_size)
    enable_alpha_blend()
    draw_image(img, image_pos.x, image_pos.y, 0xffffffff, image_size)
    disable_alpha_blend()

def draw_digit(digit; pos)
    let text = "{digit}"
    let tsize = get_text_size(text)
    let tpos = pos - 0.5 * tsize
    text_out(tpos.x, tpos.y, text, digit_colors[digit - 1])

def draw_hex(hex)
    let val = get_hex_val(hex)
    if !infinity && (val & HEX_INVALID) == HEX_INVALID
        return

    let poly = get_hex_vertices(hex)
    var color = background_color

    if (val & HEX_UNCOVERED) == HEX_UNCOVERED
        var highlight = 0x000000
        if !game_finished && hex == selected_hex && (val & HEX_UNCOVERED) == HEX_UNCOVERED
            highlight = 0x222222
        elif game_finished && (val & (HEX_FLAG | HEX_MINE)) == (HEX_FLAG | HEX_MINE)
            highlight = 0x003300
        fill_convex_polygon([[auto poly[3]; poly[4]; poly[5]; poly[0]]], 0x777777 + highlight)
        fill_convex_polygon([[auto poly[0]; poly[1]; poly[2]; poly[3]]], 0xcccccc + highlight)
        fill_convex_polygon(get_hex_vertices(hex, 0.8), 0x999999 + highlight)
        if (val & HEX_FLAG) == HEX_FLAG
            draw_image_alpha(flag_image, hex_coord_to_screen(hex))
        return
    else
        if (val & HEX_RED) == HEX_RED
            fill_convex_polygon(poly, 0xB83E3E)
        else
            fill_convex_polygon(poly, 0x717177)
        let digit = int(val & HEX_DIGITS_MASK)
        let mine = (val & HEX_MINE) == HEX_MINE
        if mine
            draw_image_alpha(mine_image, hex_coord_to_screen(hex))
        else
            if digit > 0
                draw_digit(digit, hex_coord_to_screen(hex))

    polygon(poly, 0x000000)

def draw_hexes()
    if (!infinity)
        for hex in get_all_valid_hexes()
            draw_hex(hex)
    else
        for hex in get_all_visible_hexes()
            draw_hex(hex)

def show_all_mines()
    if infinity
        return
    for hex in get_all_valid_hexes()
        let val = get_hex_val(hex)
        if (val & (HEX_FLAG | HEX_MINE)) == HEX_MINE
            set_hex_val(hex, 0u, HEX_UNCOVERED)

def mine_hit(hex)
    set_hex_val(hex, HEX_RED, HEX_RED | HEX_UNCOVERED)
    if extra_lifes <= 0 || !infinity
        game_finished = true
    else
        extra_lifes--
        return
    show_all_mines()
    game_end(false)

def check_complete()
    if infinity
        return false
    for hex in get_all_valid_hexes()
        let val = get_hex_val(hex)
        if (val & (HEX_MINE | HEX_UNCOVERED)) == HEX_UNCOVERED
            return false
    return true

def is_cover_allowed(hex_val)
    return (hex_val & HEX_UNCOVERED) == HEX_UNCOVERED && (hex_val & HEX_FLAG) != HEX_FLAG

def cover_hex(hex_coord)
    var val = get_hex_val(hex_coord, generated && infinity)
    if !is_cover_allowed(val) || (val & HEX_INVALID) == HEX_INVALID
        return
    if !generated
        generate_mines(hex_coord, num_mines)
        generated = true
        if infinity
            val = get_hex_val(hex_coord)
    if (val & HEX_MINE) == HEX_MINE
        mine_hit(hex_coord)
        return

    set_hex_val(hex_coord, 0u, HEX_UNCOVERED)
    progress++
    rounded_progress++
    if (val & HEX_DIGITS_MASK) == 0u
        var nbs1 <- get_neighbors(hex_coord)
        while !empty(nbs1)
            var nbs2 <- nbs1
            for nb in nbs2
                let val2 = get_hex_val(nb, infinity)
                if !is_cover_allowed(val2)
                    continue
                set_hex_val(nb, 0u, HEX_UNCOVERED)
                progress++
                rounded_progress++
                if (val2 & HEX_DIGITS_MASK) == 0u
                    for hex in get_neighbors(nb)
                        push(nbs1, hex)
    if check_complete()
        show_all_mines()
        game_finished = true
        game_end(true)
    if rounded_progress >= progress_for_life
        extra_lifes += rounded_progress / progress_for_life
        rounded_progress = rounded_progress % progress_for_life

def flag_hex(hex_coord)
    let val = get_hex_val(hex_coord, infinity)
    if (val & HEX_UNCOVERED) != HEX_UNCOVERED || (val & HEX_INVALID) == HEX_INVALID
        return
    set_hex_val(hex_coord, val ^ HEX_FLAG, HEX_FLAG)
    if (val & HEX_FLAG) == HEX_FLAG
        num_flags--
    else
        num_flags++

def start_game(hexes, mines: int; view_scale: float)
    restart()
    init_hexes(hexes, infinity)
    hexes_radius = hexes
    num_mines = mines
    num_flags = 0
    update_view_scale(view_scale)
    is_in_game = true
    generated = false
    game_finished = false
    image_size = 1.4 * view_scale
    extra_lifes = 0
    rounded_progress = 0
    progress = 0

def press_callback(btype: ButtonTypes): void
    infinity = false
    if btype == ButtonTypes GAME_MODE_BEGINNER
        start_game(5, 20, 30.0)
    elif btype == ButtonTypes GAME_MODE_INTERMEDIATE
        start_game(8, 50, 25.0)
    elif btype == ButtonTypes GAME_MODE_EXPERT
        start_game(11, 99, 20.0)
    elif btype == ButtonTypes GAME_MODE_INFINITY
        infinity = true
        start_game(7, 0, 25.0)
    elif btype == ButtonTypes RESTART
        if num_mines == 0
            infinity = true
        start_game(hexes_radius, num_mines, view_scale)
    elif btype == ButtonTypes MAIN_MENU
        is_in_game = false
        main_menu()

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize(is_hard_reload: bool)
    is_in_game = false
    button_pressed_callback = @@press_callback
    main_menu()
    init_images()
    if is_hard_reload
        set_window_title("HexaMine")
    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    decs_stage("update")
    if process_pressed_buttons()
        return
    if !game_finished
        if get_mouse_button_down(MB_LEFT)
            cover_hex(selected_hex)
        if get_mouse_button_down(MB_RIGHT)
            flag_hex(selected_hex)
        let mouse_coord = get_mouse_position()
        selected_hex = screen_to_hex(mouse_coord)
    let speed = 300.
    if get_key(VK_UP)
        move_view(float2(0., 1.) * dt * speed)
    if get_key(VK_DOWN)
        move_view(float2(0., -1.) * dt * speed)
    if get_key(VK_LEFT)
        move_view(float2(1., 0.) * dt * speed)
    if get_key(VK_RIGHT)
        move_view(float2(-1., 0.) * dt * speed)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    fill_rect(0, 0, get_screen_width(), get_screen_height(), background_color)
    if is_in_game
        set_font_size(view_scale)
        draw_hexes()
        if !infinity
            text_out(10., 10., "Mines left: {num_mines - num_flags}", 0xffffff)
        else
            enable_alpha_blend()
            fill_rect(0., 0., 350., 180., background_color + 0x99000000)
            fill_rect(0, get_screen_height() - 50, get_screen_width(), 50, background_color + 0x99000000)
            disable_alpha_blend()
            text_out(10., 10., "Mines left: ∞", 0xffffff)
            text_out(10., 50., "Flags count: {num_flags}", 0xffffff)
            text_out(10., 90., "Opened hexes: {progress}", 0xffffff)
            text_out(10., 130., "Extra lifes: {extra_lifes} ({rounded_progress * 100 / progress_for_life}%)", 0xffffff)
            text_out(10, get_screen_height() - 45, "Use arrows (←, ↑, →, ↓) to move screen", 0xffffff)
        if game_finished
            let middle = float2(get_screen_width(), get_screen_height()) * 0.5
            let panel_size = float2(300., 250.)
            var pos = middle - panel_size * 0.5
            enable_alpha_blend()
            fill_rect(pos.x, pos.y, panel_size.x, panel_size.y, background_color + 0x99000000)
            disable_alpha_blend()

    decs_stage("draw")
    return
