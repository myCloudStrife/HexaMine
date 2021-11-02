require daslib/media

var
    mine_image: Image
    flag_image: Image


def init_images()
    mine_image <- create_image("mine.png")
    flag_image <- create_image("flag.png")
    pass
