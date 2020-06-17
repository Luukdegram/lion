# ![logo](https://github.com/Luukdegram/lion/blob/master/assets/zero_lion.png "Lion Chip-8 Emulator") Lion #

Lion is a CHIP-8 emulator written in [Zig](https://ziglang.org). It uses OpenGL with GLFW for rendering and [OpenAL](https://www.openal.org/) for audio support.
The keypad uses the original keypad and can currently not be customized. Meaning the following keys are available:

1 | 2 | 3 | C

4 | 6 | 7 | D

7 | 8 | 9 | E

A | 0 | B | F

It also supports the following keys:
- Esc: Closes the window
- P: Pauses the cpu
- M: Mutes the audio

## Running rom's ##

To run the example rom you can use
```bash
> zig build run
````

To use your own rom:
```bash
> zig build
> ./zig-cache/bin/lion <path_to_rom>
```

Currently I've only been testing on Linux.
Adding support to Windows/MacOS should be fairly simple by modifying the build.zig file (as long as MacOS still supports OpenGL).

### Dependencies ###

* [Zig](https://ziglang.org) (master branch)
* [Epoxy](https://github.com/anholt/libepoxy)
* [GLFW](https://www.glfw.org/)
* [OpenAL](https://www.openal.org/)
* [dr_wav](https://github.com/mackron/dr_libs) (*included in repo* wave file loading).

### credits ###
- Audio source: https://audiosoundclips.com/8-bit-game-sound-effects-sfx/ (Game Effect 10).
- Test ROM:
https://github.com/corax89/chip8-test-rom
- Original logo: https://github.com/ziglang/logo

### references ###
1. [Mastering CHIP-8](http://mattmik.com/files/chip8/mastering/chip8.html)
2. [Cowgod's Chip-8 Technical Reference v1.0](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
3. [Building a Chip-8 Emulator](https://austinmorlan.com/posts/chip8_emulator/)




