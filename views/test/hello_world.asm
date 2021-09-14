@section .data

format: db "%s", 0x0A, 0x00
hello_word: db "Hello, world!", 0x0A, 0x00

%define DUMMY "THICC"

@section .text
@global _main
@extern printf

_main:
    lea rcx, [format * 2 + 2 * 2]
    lea rdx, [hello_word]
    call [printf]
    ret