# vda-zig

A library for the Windows virtual desktop API. The Windows shell exposes virtual desktops only through undocumented COM interfaces that shift between builds, and [docs/internals.md](docs/internals.md) maps them on Windows 11 build 26100. The library enumerates, switches, creates, removes, renames, and reorders desktops, sets their wallpapers, moves and pins windows, and reports changes through notifications. The service reconnects automatically when the shell restarts.
