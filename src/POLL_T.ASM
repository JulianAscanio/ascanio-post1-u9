; POLL_T.ASM - Polling con timeout configurable para el puerto de teclado 8042
; Compilar: nasm -f bin src\POLL_T.ASM -o bin\POLL_T.COM
[BITS 16]
[ORG 0x100]

KB_DATA_PORT    EQU 60h
KB_STATUS_PORT  EQU 64h
KB_OBF_MASK     EQU 01h
MAX_RETRY       EQU 0005h           ; valor reducido para verificar timeout sin tecla

section .data
    msg_timeout db "Timeout: sin respuesta del dispositivo", 0Dh, 0Ah, "$"
    msg_dato    db "Dato leido (hex): $"
    crlf        db 0Dh, 0Ah, "$"

section .text
start:
    ; Vaciar residuo previo del buffer 8042 si existiera
    in  al, KB_STATUS_PORT
    test al, KB_OBF_MASK
    jz  .iniciar_poll
    in  al, KB_DATA_PORT

.iniciar_poll:
    mov cx, MAX_RETRY

.poll:
    in  al, KB_STATUS_PORT
    test al, KB_OBF_MASK
    jnz .dato_listo
    loop .poll                      ; decrementa CX; repite mientras CX != 0

    ; Timeout: CX llego a 0 sin dato disponible
    mov ah, 09h
    mov dx, msg_timeout
    int 21h
    jmp .fin

.dato_listo:
    in  al, KB_DATA_PORT
    mov bl, al
    mov ah, 09h
    mov dx, msg_dato
    int 21h

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

.fin:
    mov ah, 4Ch
    xor al, al
    int 21h
