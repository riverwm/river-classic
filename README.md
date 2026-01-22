# river-classic

river-classic is a dynamic tiling Wayland compositor with flexible runtime
configuration.

It is a fork of [river](https://codeberg.org/river/river) 0.3 intended for users
that are happy with how river 0.3 works and do not wish to deal with the majorly
breaking changes planned for the river 0.4.0 release.

Join us at [#river](https://web.libera.chat/?channels=#river) on irc.libera.chat —
Read our man pages, [wiki](https://codeberg.org/river/wiki-classic), and
[Code of Conduct](CODE_OF_CONDUCT.md)

The main repository is on [codeberg](https://codeberg.org/river/river-classic),
which is where the issue tracker may be found and where contributions are accepted.

Read-only mirrors exist on [sourcehut](https://git.sr.ht/~ifreund/river-classic)
and [github](https://github.com/riverwm/river-classic).

## Features

river-classic's window management style is quite similar to
[dwm](http://dwm.suckless.org), [xmonad](https://xmonad.org), and other classic
dynamic tiling X11 window managers. Windows are automatically arranged in a tiled
layout and shifted around as windows are opened/closed.

Rather than having the tiled layout logic built into the compositor process,
river-classic uses a [custom Wayland
protocol](https://codeberg.org/river/river-classic/src/branch/main/protocol/river-layout-v3.xml)
and separate "layout generator" process. A basic layout generator, `rivertile`,
is provided but users are encouraged to use community-developed [layout
generators](https://codeberg.org/river/wiki-classic/src/branch/main/pages/Community-Layouts.md)
or write their own. Examples in C and Python may be found
[here](https://codeberg.org/river/river-classic/src/branch/main/contrib).

Tags are used to organize windows rather than workspaces. A window may be
assigned to one or more tags. Likewise, one or more tags may be displayed on a
monitor at a time.

river-classic is configured at runtime using the `riverctl` tool. It can define
keybindings, set the active layout generator, configure input devices, and more.
On startup, river-classic runs a user-defined init script which usually runs
`riverctl` commands to set up the user's configuration.

## Building

Note: If you are packaging river-classic for distribution, see [PACKAGING.md](PACKAGING.md).

To compile river-classic first ensure that you have the following dependencies
installed. The "development" versions are required if applicable to your
distribution.

- [zig](https://ziglang.org/download/) 0.15
- wayland
- wayland-protocols
- [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots) 0.19
- xkbcommon
- libevdev
- pixman
- pkg-config
- scdoc (optional, but required for man page generation)

Then run, for example:
```
zig build -Doptimize=ReleaseSafe --prefix ~/.local install
```
To enable Xwayland support pass the `-Dxwayland` option as well.
Run `zig build -h` to see a list of all options.

## Usage

River can either be run nested in an X11/Wayland session or directly
from a tty using KMS/DRM. Simply run the `river` command.

On startup river-classic will run an executable file at `$XDG_CONFIG_HOME/river/init`
if such an executable exists. If `$XDG_CONFIG_HOME` is not set,
`~/.config/river/init` will be used instead.

Usually this executable is a shell script invoking *riverctl*(1) to create
mappings, start programs such as a layout generator or status bar, and
perform other configuration.

An example init script with sane defaults is provided [here](example/init)
in the example directory.

For complete documentation see the `river(1)`, `riverctl(1)`, and
`rivertile(1)` man pages.

## Donate

If my work on river-classic adds value to your life and you'd like to support me
financially you can find donation information [here](https://isaacfreund.com/donate/).

## Licensing

river-classic is released under the GNU General Public License v3.0 only.

The protocols in the `protocol` directory are released under various licenses by
various parties. You should refer to the copyright block of each protocol for
the licensing information. The protocols prefixed with `river` and developed by
this project are released under the ISC license (as stated in their copyright
blocks).

The river logo is licensed under the CC BY-SA 4.0 license, see the
[license](logo/LICENSE) in the logo directory.
