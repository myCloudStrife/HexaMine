require daslib/media
require daslib/decs_boost

let
    HEX_DIGITS_MASK = 0x0007
    HEX_MINE        = 0x0010
    HEX_UNCOVERED   = 0x0020
    HEX_FLAG        = 0x0040
    HEX_RED         = 0x0080
    HEX_INVALID     = 0x0100 //not drawable

struct Tile
    coord: int2
    hexes: array<uint>

var
    use_tiles = false
    hexes: array<uint>
    game_size = 11 // tile_size
    view_offset = float2(0., 0.)
    view_scale = 20.0
    seed: int4
    tiles: table<uint; Tile>
    mine_rate = 0.257

def is_valid_hex(hex_coord: int2)
    return (get_hex_val(hex_coord) & HEX_INVALID) != HEX_INVALID

def is_valid_hex(linear_coord: int)
    assert(linear_coord >= 0 && linear_coord < length(hexes))
    return (hexes[linear_coord] & HEX_INVALID) != HEX_INVALID

def init_hexes(game_size_radius; _use_tiles: bool = false)
    clear(tiles)
    use_tiles = _use_tiles
    game_size = game_size_radius * 2 + 1
    hexes |> resize(game_size * game_size)
    for i in range(game_size)
        for j in range(game_size)
            var hex: uint& = hexes[i * game_size + j]
            hex = HEX_UNCOVERED
            if i + j < game_size / 2 || i + j >= game_size * 3 / 2
                hex |= HEX_INVALID

    if !use_tiles
        var tile: Tile
        tile.coord = int2(0,0)
        tile.hexes := hexes
        tiles[0u] <- tile
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

def generate_tile(tile_coord: int2; tilekey: uint; elem: int)
    if key_exists(tiles, tilekey)
        return HEX_INVALID
    var tile: Tile
    tile.coord = tile_coord
    resize(tile.hexes, game_size * game_size)
    for hex in tile.hexes
        hex = HEX_UNCOVERED
        if random_float(seed) < mine_rate
            hex |= HEX_MINE

    tiles[tilekey] := tile

    for i in range(length(tile.hexes))
        let hex_coord = int2(i / game_size, i % game_size) + tile_coord * game_size
        let hex_val = tile.hexes[i]
        var nbs <- get_neighbors(hex_coord)
        var d = 0u
        if (hex_val & HEX_MINE) == HEX_MINE
            for nb in nbs
                let nb_tile = get_tile_coord(nb)
                if tile_coord != nb_tile && key_exists(tiles, make_tilekey(nb_tile))
                    d = (get_hex_val(nb) & HEX_DIGITS_MASK)
                    set_hex_val(nb, d + 1u, HEX_DIGITS_MASK)
        else
            for nb in nbs
                if (get_hex_val(nb) & HEX_MINE) == HEX_MINE
                    d++
        tile.hexes[i] = (tile.hexes[i] & ~HEX_DIGITS_MASK) | d

    let ret = tile.hexes[elem]
    tiles[tilekey] <- tile
    return ret

def get_tile_coord(hex_coord: int2)
    let n = game_size - 1
    let shifted = int2(hex_coord.x >= 0 ? hex_coord.x : hex_coord.x - n,
                       hex_coord.y >= 0 ? hex_coord.y : hex_coord.y - n)
    return int2(shifted.x / game_size, shifted.y / game_size)

def make_tilekey(tile_coord: int2)
    return ((0xffff & uint(tile_coord.x)) << 16u) | (0xffff & uint(tile_coord.y))

def get_hex_val(hex_coord: int2; generate: bool = false)
    let n = game_size - 1
    let shifted = int2(hex_coord.x >= 0 ? hex_coord.x : hex_coord.x - n,
                       hex_coord.y >= 0 ? hex_coord.y : hex_coord.y - n)
    let tile_coord = int2(shifted.x / game_size, shifted.y / game_size)
    let tilekey = ((0xffff & uint(tile_coord.x)) << 16u) | (0xffff & uint(tile_coord.y))
    var tile: Tile const? = find(tiles, tilekey)
    if !generate && tile == null
        return use_tiles ? HEX_UNCOVERED : HEX_INVALID
    let in_tile_coord = hex_coord - tile_coord * game_size
    let linear_coord = in_tile_coord.x * game_size + in_tile_coord.y

    if generate
        if in_tile_coord.x == 0 && in_tile_coord.y == n && find(tiles, make_tilekey(tile_coord + int2(-1, 1))) == null
            generate_tile(tile_coord + int2(-1, 1), make_tilekey(tile_coord + int2(-1, 1)), 0)
        if in_tile_coord.x == n && in_tile_coord.y == 0 && find(tiles, make_tilekey(tile_coord + int2(-1, 1))) == null
            generate_tile(tile_coord + int2(-1, 1), make_tilekey(tile_coord + int2(-1, 1)), 0)
        if in_tile_coord.x == 0 && find(tiles, make_tilekey(tile_coord + int2(-1, 0))) == null
            generate_tile(tile_coord + int2(-1, 0), make_tilekey(tile_coord + int2(-1, 0)), 0)
        elif in_tile_coord.x == n && find(tiles, make_tilekey(tile_coord + int2(1, 0))) == null
            generate_tile(tile_coord + int2(1, 0), make_tilekey(tile_coord + int2(1, 0)), 0)
        if in_tile_coord.y == 0 && find(tiles, make_tilekey(tile_coord + int2(0, -1))) == null
            generate_tile(tile_coord + int2(0, -1), make_tilekey(tile_coord + int2(0, -1)), 0)
        elif in_tile_coord.y == n && find(tiles, make_tilekey(tile_coord + int2(0, 1))) == null
            generate_tile(tile_coord + int2(0, 1), make_tilekey(tile_coord + int2(0, 1)), 0)

    if tile == null
        return generate_tile(tile_coord, tilekey, linear_coord)
    return deref(tile).hexes[linear_coord]

def set_hex_val(hex_coord: int2; val: uint; mask: uint = 0xffffffff)
    let tile_coord = get_tile_coord(hex_coord)
    let in_tile_coord = hex_coord - tile_coord * game_size
    let linear_coord = in_tile_coord.x * game_size + in_tile_coord.y
    var found = false
    find_for_edit_if_exists(tiles, make_tilekey(tile_coord)) <| $(tile)
        tile.hexes[linear_coord] = tile.hexes[linear_coord] & ~mask | val
        found = true

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

def get_all_visible_hexes()
    var lbTile = get_tile_coord(screen_to_hex(float2(0.0, float(get_screen_height()))))
    var rtTile = get_tile_coord(screen_to_hex(float2(float(get_screen_width()), 0.0)))
    var visTiles: array<int2>
    for i in range(rtTile.x - lbTile.x + 1)
        for j in range(lbTile.y - rtTile.y + 1)
            push(visTiles, int2(i + lbTile.x, j + rtTile.y))

    var visHexes: array<int2>
    for tile in visTiles
        for i in range(game_size)
            for j in range (game_size)
                push(visHexes, tile * game_size + int2(i, j))

    return <- visHexes

def recalc_digit(hex: int2)
    var d = 0u
    for nb in get_neighbors(hex)
        if (get_hex_val(nb) & HEX_MINE) == HEX_MINE
            d++
    set_hex_val(hex, d, HEX_DIGITS_MASK)

def generate_mines(safe_hex: int2; num_mines: int)
    if use_tiles
        // clear(tiles)
        var tile_coord = get_tile_coord(safe_hex)
        generate_tile(tile_coord + int2( 0, 0), make_tilekey(tile_coord + int2( 0, 0)), 0)
        generate_tile(tile_coord + int2(-1, 0), make_tilekey(tile_coord + int2(-1, 0)), 0)
        generate_tile(tile_coord + int2(-1,-1), make_tilekey(tile_coord + int2(-1,-1)), 0)
        generate_tile(tile_coord + int2( 0,-1), make_tilekey(tile_coord + int2( 0,-1)), 0)
        generate_tile(tile_coord + int2( 1,-1), make_tilekey(tile_coord + int2( 1,-1)), 0)
        generate_tile(tile_coord + int2( 1, 0), make_tilekey(tile_coord + int2( 1, 0)), 0)
        generate_tile(tile_coord + int2( 1, 1), make_tilekey(tile_coord + int2( 1, 1)), 0)
        generate_tile(tile_coord + int2( 0, 1), make_tilekey(tile_coord + int2( 0, 1)), 0)
        generate_tile(tile_coord + int2(-1, 1), make_tilekey(tile_coord + int2(-1, 1)), 0)
        set_hex_val(safe_hex, HEX_UNCOVERED)

        for nb in get_neighbors(safe_hex)
            set_hex_val(nb, 0u, HEX_MINE)
        for nb in get_neighbors(safe_hex)
            var d = 0u
            recalc_digit(nb)
            for nb2 in get_neighbors(nb)
                recalc_digit(nb2)
        return

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


def move_view(delta)
    view_offset += delta