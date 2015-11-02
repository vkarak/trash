# trash
A command-line utility to manage the trash bin on KDE/GNOME.

This is a bash script I developed several years ago for controlling Linux's "Trash" bin from the command line. Back then I was using KDE, where I have developed it, but works fine also on recent GNOME's.

    $ trash --help
    Usage: trash [OPTION]... FILE...
    Move FILE(s) to trash.
    -d [delete-list], --delete=[delete-list]  permanently remove files from trash.
    -e, --empty     empty the trash.
    -f, --force     do not prompt for confirmaton on delete or empty.
    -h, --help      display this help message.
    -l, --list      display a listing of the contents of the trash.
    -r [restore-list], --restore=[restore-list] restore files from trash.
    -u, --usage     display trash usage.
    -v, --version   print version number.

For more details, check the accompanying man page:

    $ man -M man trash
