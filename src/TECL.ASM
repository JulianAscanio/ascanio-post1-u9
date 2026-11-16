; TECL.ASM - Lectura del puerto de estado del teclado 8042 por polling
; Compilar: nasm -f bin src\TECL.ASM -o bin\TECL.COM
[BITS 16]
[ORG 0x100]

KB_DATA_PORT    EQU 60h
KB_STATUS_PORT  EQU 64h
KB_OBF_MASK     EQU 01h

section .data
    msg_prompt  db "Presione una tecla (polling puerto 64h)...$"
    msg_scan    db 0Dh, 0Ah, "Scancode leido (hex): $"
    crlf        db 0Dh, 0Ah, "$"

section .text
start:
    mov ah, 09h
    mov dx, msg_prompt
    int 21h

    ; Deshabilitar interrupciones para que INT 09h del BIOS no consuma el scancode
    cli

    ; Vaciar cualquier dato previo antes de esperar la nueva pulsacion
    in  al, KB_STATUS_PORT
    test al, KB_OBF_MASK
    jz  .poll
    in  al, KB_DATA_PORT

    ; Esperar hasta que OBF=1 (dato disponible en el buffer de salida del 8042)
.poll:
    in  al, KB_STATUS_PORT
    test al, KB_OBF_MASK
    jz  .poll

    in  al, KB_DATA_PORT
    sti                             ; rehabilitar interrupciones
    mov bl, al                      ; guardar scancode en BL

    mov ah, 09h
    mov dx, msg_scan
    int 21h

    ; Mostrar scancode en hexadecimal (nibble alto y bajo)
    mov ah, 02h
    mov dl, bl
    shr dl, 4
    add dl, 30h
    cmp dl, 3Ah
    jl  .printH
    add dl, 07h
.printH:
    int 21h

    mov dl, bl
    and dl, 0Fh
    add dl, 30h
    cmp dl, 3Ah
    jl  .printL
    add dl, 07h
.printL:
    int 21h

    mov ah, 09h
    mov dx, crlf
    int 21h

    mov ah, 4Ch
    xor al, al
    int 21h
