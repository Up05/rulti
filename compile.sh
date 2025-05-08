#!/bin/sh

# Do not compile, if you are a user of the library!
# Simply import "path/to/here"

clear
odin build . -linker:lld -o:none -debug -out:test-exe && ./test-exe
