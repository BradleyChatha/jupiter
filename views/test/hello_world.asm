@section .data

hello: db "Hello, world", 0x0A, 0x00

@section .text

_main:
    add al, 2
    add eax, -2
    add dword r8, -2
    add r8, r9
    ret