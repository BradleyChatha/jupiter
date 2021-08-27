@section .data

hello: db "Hello, world", 0x0A, 0x00

@section .text

_main:
    lea rax, [hello]
    ret