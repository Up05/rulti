#!/bin/sh
odin build . -debug -linker:mold -o:speed -no-bounds-check && ./rulti
# -o:speed -no-bounds-check
