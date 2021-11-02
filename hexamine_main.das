require daslib/media
require hexes
require images
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code

let
    background_color = 0x333333
    digit_colors = [[auto 0x0000FF;
                          0x42CA42;
                          0xFF2018;
                          0x19A3DA;
                          0xC71DBD;
                          0xCFA227]]

var
    selected_hex = int2(-1, -1)
    wrong_hex = int2(-1, -1)
    generated = false
    game_finished = false
    image_size = 1.0

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
    if (val & HEX_INVALID) == HEX_INVALID
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
        if hex == wrong_hex
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
    for hex in get_all_valid_hexes()
        draw_hex(hex)

    // for hex in get_all_valid_hexes()
    //     let poly = get_hex_vertices(hex)
    //     polygon(poly, 0x000000)

def show_all_mines()
    for hex in get_all_valid_hexes()
        let val = get_hex_val(hex)
        if (val & (HEX_FLAG | HEX_MINE)) == HEX_MINE
            set_hex_val(hex, 0u, HEX_UNCOVERED)

def mine_hit(hex)
    wrong_hex = hex
    game_finished = true
    show_all_mines()

def check_complete()
    for hex in get_all_valid_hexes()
        let val = get_hex_val(hex)
        if (val & (HEX_MINE | HEX_UNCOVERED)) == HEX_UNCOVERED
            return false
    return true

def is_cover_allowed(hex_val)
    return (hex_val & HEX_UNCOVERED) == HEX_UNCOVERED && (hex_val & HEX_FLAG) != HEX_FLAG

def cover_hex(hex_coord)
    let val = get_hex_val(hex_coord)
    if !is_cover_allowed(val) || (val & HEX_INVALID) == HEX_INVALID
        return
    if !generated
        generate_mines(hex_coord, 99)
        generated = true
    if (val & HEX_MINE) == HEX_MINE
        mine_hit(hex_coord)
        return

    set_hex_val(hex_coord, 0u, HEX_UNCOVERED)
    if (val & HEX_DIGITS_MASK) == 0u
        var nbs1 <- get_neighbors(hex_coord)
        while !empty(nbs1)
            var nbs2 <- nbs1
            for nb in nbs2
                let val2 = get_hex_val(nb)
                if !is_cover_allowed(val2)
                    continue
                set_hex_val(nb, 0u, HEX_UNCOVERED)
                if (val2 & HEX_DIGITS_MASK) == 0u
                    for hex in get_neighbors(nb)
                        push(nbs1, hex)
    if check_complete()
        show_all_mines()
        game_finished = true

def flag_hex(hex_coord)
    let val = get_hex_val(hex_coord)
    if (val & HEX_UNCOVERED) != HEX_UNCOVERED || (val & HEX_INVALID) == HEX_INVALID
        return
    set_hex_val(hex_coord, val ^ HEX_FLAG, HEX_FLAG)

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize(is_hard_reload: bool)
    init_hexes(11)
    init_images()
    image_size = 1.4 * view_scale
    set_font_size(view_scale)
    generated = false
    if is_hard_reload
        set_window_title("HexaMine")
    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    //if !game_finished
    if get_mouse_button_down(MB_LEFT)
        cover_hex(selected_hex)
    if get_mouse_button_down(MB_RIGHT)
        flag_hex(selected_hex)
    let mouse_coord = get_mouse_position()
    selected_hex = screen_to_hex(mouse_coord)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    fill_rect(0, 0, get_screen_width(), get_screen_height(), background_color)
    draw_hexes()
    return
