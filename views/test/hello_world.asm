@section .data

format: db "%s", 0x0A, 0x00
hello_word: db "Hello, world!", 0x0A, 0x00

@section .text
@global _main
@extern printf

_main:
    lea rcx, [format]
    lea rdx, [hello_word]
    call [printf]
    ret