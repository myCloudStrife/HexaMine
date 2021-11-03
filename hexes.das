require daslib/media

let
    HEX_DIGITS_MASK = 0x0007
    HEX_MINE        = 0x0010
    HEX_UNCOVERED   = 0x0020
    HEX_FLAG        = 0x0040
    HEX_INVALID     = 0x0100 //not drawable

var
    hexes: array<uint>
    game_size = 11
    view_offset = float2(0., 0.)
    view_scale = 20.0
    seed: int4

def is_valid_hex(hex_coord: int2)
    return (get_hex_val(hex_coord) & HEX_INVALID) != HEX_INVALID

def is_valid_hex(linear_coord: int)
    assert(linear_coord >= 0 && linear_coord < length(hexes))
    return (hexes[linear_coord] & HEX_INVALID) != HEX_INVALID

def init_hexes(game_size_radius)
    game_size = game_size_radius * 2 + 1
    hexes |> resize(game_size * game_size)
    for i in range(game_size)
        for j in range(game_size)
            var hex: uint& = hexes[i * game_size + j]
            hex = HEX_UNCOVERED
            if i + j < game_size / 2 || i + j >= game_size * 3 / 2
                hex |= HEX_INVALID
    update_view_scale(20.0)

def update_view_scale(vs: float)
    view_offset = float2(0.0)
    view_scale = vs
    view_offset -= hex_coord_to_screen(int2(game_size / 2))
    view_offset += float2(get_screen_width(), get_screen_height()) * 0.5

def hex_coord_to_screen(hex_coord: int2)
    let coord = (float(hex_coord.x) * float2(sqrt(3.0), 0.0) + float(hex_coord.y) * float2(sqrt(3.0)/2.0, 1.5))
    return coord * view_scale + view_offset

def hex_round(hex_coord: float2)
    let cude_hex = float3(hex_coord.x, -hex_coord.x - hex_coord.y, hex_coord.y)
    var rcube = roundi(cude_hex)
    let diff = abs(float3(rcube) - cude_hex)
    if diff.x > diff.y && diff.x > diff.z
        rcube.x = -rcube.y - rcube.z
    elif diff.y > diff.z
        rcube.y = -rcube.x - rcube.z
    else
        rcube.z = -rcube.x - rcube.y
    return int2(rcube.x, rcube.z)

def screen_to_hex(screen_coord: float2): int2
    let coord = (screen_coord - view_offset) / view_scale
    let hex_float = coord.x * float2(1./sqrt(3.), 0.) + coord.y * float2(-1./3., 2./3.)
    return hex_round(hex_float)

def get_hex_vertices(hex_coord: int2; scale: float = 1.0)
    let center = hex_coord_to_screen(hex_coord)
    return [[float2[6] center + scale * view_scale * float2(-sqrt(3.0)*0.5, 0.5);
                       center + scale * view_scale * float2(-sqrt(3.0)*0.5, -0.5);
                       center + scale * view_scale * float2(0, -1);
                       center + scale * view_scale * float2(sqrt(3.0)*0.5, -0.5);
                       center + scale * view_scale * float2(sqrt(3.0)*0.5, 0.5);
                       center + scale * view_scale * float2(0, 1)]]

def get_hex_val(hex_coord: int2)
    let linear_coord = hex_coord.x * game_size + hex_coord.y
    if hex_coord.x < 0 || hex_coord.x >= game_size || hex_coord.y < 0 || hex_coord.y >= game_size
        return HEX_INVALID
    return hexes[linear_coord]

def set_hex_val(hex_coord: int2; val: uint; mask: uint = 0xffffffff)
    let linear_coord = hex_coord.x * game_size + hex_coord.y
    assert(linear_coord >= 0 && linear_coord < hexes |> length())
    hexes[linear_coord] = hexes[linear_coord] & ~mask | val

def get_neighbors(hex_coord: int2)
    var arr: array<int2>
    let neighbors = [[int2[6] hex_coord + int2(-1,0);
                              hex_coord + int2(0,-1);
                              hex_coord + int2(1,-1);
                              hex_coord + int2(1,0);
                              hex_coord + int2(0,1);
                              hex_coord + int2(-1,1)]]
    for neighbor in neighbors
        if is_valid_hex(neighbor)
            arr |> push(neighbor)
    return <- arr

def get_all_valid_hexes()
    return <- [{ for i in range(length(hexes)); int2(i / game_size, i % game_size); where is_valid_hex(i) }]

def generate_mines(safe_hex: int2; num_mines: int)
    verify(is_valid_hex(safe_hex))
    var neighbors <- get_neighbors(safe_hex)
    var valid_hexes <- get_all_valid_hexes()
    valid_hexes |> erase(valid_hexes |> find_index(safe_hex))
    for nb in neighbors
        valid_hexes |> erase(valid_hexes |> find_index(nb))
    randomize_seed(seed)
    assert(num_mines <= length(valid_hexes))
    for i in range(num_mines)
        let ri = random_int(seed) % length(valid_hexes)
        set_hex_val(valid_hexes[ri], HEX_MINE, HEX_MINE)
        erase(valid_hexes, ri)

    valid_hexes <- get_all_valid_hexes()
    for hex in valid_hexes
        neighbors <- get_neighbors(hex)
        var digit = 0u
        for nb in neighbors
            if (get_hex_val(nb) & HEX_MINE) == HEX_MINE
                digit++
        set_hex_val(hex, digit, HEX_DIGITS_MASK)
