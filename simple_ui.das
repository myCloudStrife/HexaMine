require daslib/media
require daslib/decs_boost

enum ButtonTypes
    GAME_MODE_BEGINNER
    GAME_MODE_INTERMEDIATE
    GAME_MODE_EXPERT
    GAME_MODE_INFINITY
    RESTART
    MAIN_MENU

var
    button_pressed_callback: function < (arg1:ButtonTypes):void >
    pressed_buttons: array<ButtonTypes>

[decs_template]
struct Button
    pos: float2
    text: string
    size: float2
    butType: ButtonTypes

[decs_template]
struct Text
    pos: float2
    text: string
    color: uint
    fontSize: float

def main_menu()
    restart()
    set_font_size(20)
    let offset = float2(0, get_screen_height()) * 0.15
    var middle = float2(get_screen_width(), get_screen_height()) * 0.5
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Text pos = middle - float2(70.0, 280.0), text = "Hexagonal",
                                   color = 0xffffff, fontSize = 40.0]])
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Text pos = middle - float2(-30.0, 220.0), text = "Minesweeper",
                                   color = 0xffffff, fontSize = 40.0]])
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Button pos = middle - offset, text = "Beginner",
                                   size = float2(200.0, 70.0),
                                   butType = ButtonTypes GAME_MODE_BEGINNER]])
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Button pos = middle, text = "Intermediate",
                                   size = float2(200.0, 70.0),
                                   butType = ButtonTypes GAME_MODE_INTERMEDIATE]])
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Button pos = middle + offset, text = "Expert",
                                   size = float2(200.0, 70.0),
                                   butType = ButtonTypes GAME_MODE_EXPERT]])
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Button pos = middle + 2.0 * offset, text = "Infinity",
                                   size = float2(200.0, 70.0),
                                   butType = ButtonTypes GAME_MODE_INFINITY]])

def game_end(win)
    var text = "You died"
    var color = 0xff0000
    if win
        text = "You win!!!"
        color = 0x00ff00
    let middle = float2(get_screen_width(), get_screen_height()) * 0.5
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Text pos = middle - float2(0.0, 65.0), text = text,
                                   color = color, fontSize = 40.0]])
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Button pos = middle + float2(0., 10.), text = "Restart",
                                   size = float2(170.0, 50.0),
                                   butType = ButtonTypes RESTART]])
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Button pos = middle + float2(0., 80.), text = "Main menu",
                                   size = float2(170.0, 50.0),
                                   butType = ButtonTypes MAIN_MENU]])


def is_inside_button(bpos; bsize; pos)
    let lt = bpos - bsize * 0.5
    let rb = bpos + bsize * 0.5
    return pos.x >= lt.x && pos.x <= rb.x && pos.y >= lt.y && pos.y <= rb.y

def process_pressed_buttons()
    var any = false
    for btype in pressed_buttons
        invoke(button_pressed_callback, btype)
        any = true
    clear(pressed_buttons)
    return any

[decs(stage = update)]
def check_button_pressed(var b: Button)
    let mouse = get_mouse_position()
    let bsize = max(b.size, get_text_size(b.text))
    if is_inside_button(b.pos, bsize, mouse) && get_mouse_button_down(MB_LEFT)
        push(pressed_buttons, b.butType)

[decs(stage = draw)]
def draw_button(var b: Button)
    let bsize = max(b.size, get_text_size(b.text))
    let lt = b.pos - bsize * 0.5
    let rb = b.pos + bsize * 0.5
    var color = 0x777777
    if is_inside_button(b.pos, bsize, get_mouse_position())
        color += 0x333333
    fill_rect(lt.x, lt.y, bsize.x, bsize.y, color)

    set_font_size(20.0)
    let tsize = get_text_size(b.text)
    let tpos = b.pos - 0.5 * tsize
    text_out(tpos.x, tpos.y, b.text, 0xffffff)

[decs(stage = draw)]
def draw_text(var t: Text)
    set_font_size(t.fontSize)
    let tsize = get_text_size(t.text)
    let tpos = t.pos - 0.5 * tsize
    text_out(tpos.x, tpos.y, t.text, t.color)