# Chip8 emulator

This is a Chip8 emulator written in Zig. It should run most ROMs (that I've
tested anyway) and passes most tests.

It uses SDL2 as the rendering/sound/input engine.

[demo.webm](https://github.com/user-attachments/assets/5c61aacd-1fdc-44d6-b87d-50f191be7004)

### Development

There is a `nix` flake. Grab a shell with:
```
$ nix develop
```

### Running

1. Build the source via:
```
$ zig build [--release=fast]
```

2. Then run, passing a ROM as an argument:
```
$ ./zig-out/bin/chipz ./roms/5-Space_Invaders.ch8
```
