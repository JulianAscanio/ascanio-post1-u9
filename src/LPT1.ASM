; LPT1.ASM - Envio de un caracter al puerto paralelo LPT1 (protocolo Centronics)
; Compilar: nasm -f bin src\LPT1.ASM -o bin\LPT1.COM
[BITS 16]
[ORG 0x100]

LPT_DATA_PORT   EQU 0378h
LPT_STATUS_PORT EQU 0379h
LPT_CTRL_PORT   EQU 037Ah
LPT_BUSY_MASK   EQU 80h
CHAR_ENVIO      EQU 41h             ; caracter 'A'

section .data
    msg_ok      db "LPT1 (0378h): caracter 'A' enviado con pulso STROBE OK.", 0Dh, 0Ah, "$"

section .text
start:
    ; Esperar a que BUSY#=1 (bit 7 de 0379h: impresora lista)
    mov dx, LPT_STATUS_PORT
.wait_ready:
    in  al, dx
    test al, LPT_BUSY_MASK
    jz  .wait_ready

    ; Colocar el dato en el registro de datos 0378h
    mov dx, LPT_DATA_PORT
    mov al, CHAR_ENVIO
    out dx, al

    ; Generar pulso STROBE# (bit 0 del registro de control 037Ah, activo en bajo)
    mov dx, LPT_CTRL_PORT
    in  al, dx
    and al, 0FEh                    ; STROBE# = 0 (activo)
    out dx, al

    ; Retardo minimo (>1 us en DOSBox)
    mov cx, 000Fh
.delay:
    loop .delay

    or  al, 01h                     ; STROBE# = 1 (inactivo)
    out dx, al

    mov ah, 09h
    mov dx, msg_ok
    int 21h

    mov ah, 4Ch
    xor al, al
    int 21h
