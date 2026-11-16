; MULTI_ST.ASM - Polling combinado de dos puertos de estado (8042 + LPT1) con OR
; Compilar: nasm -f bin src\MULTI_ST.ASM -o bin\MULTI_ST.COM
[BITS 16]
[ORG 0x100]

KB_STATUS_PORT  EQU 64h
KB_OBF_MASK     EQU 01h
LPT_STATUS_PORT EQU 0379h
LPT_BUSY_MASK   EQU 80h

section .data
    msg_tecl    db "Teclado listo (OBF=1).", 0Dh, 0Ah, "$"
    msg_lpt1    db "LPT1 listo (BUSY#=1).", 0Dh, 0Ah, "$"

section .text
start:
    mov dx, LPT_STATUS_PORT

.poll:
    ; Bandera de teclado: bit 0 (OBF) del puerto 64h
    in  al, KB_STATUS_PORT
    and al, KB_OBF_MASK
    mov bl, al                      ; BL = bandera_teclado (0 o 1)

    ; Bandera de LPT1: bit 7 (BUSY#) del puerto 0379h (via DX)
    in  al, dx
    and al, LPT_BUSY_MASK
    shr al, 7                       ; normalizar a 0 o 1
    mov bh, al                      ; BH = bandera_lpt1 (0 o 1)

    ; Combinacion con OR: solo es 0 si ambos dispositivos estan ocupados
    mov al, bl
    or  al, bh
    jz  .poll

    ; Examinar banderas individuales tras salir del bucle
    test bl, bl
    jz  .solo_lpt1
    mov ah, 09h
    mov dx, msg_tecl
    int 21h

.solo_lpt1:
    test bh, bh
    jz  .fin
    mov ah, 09h
    mov dx, msg_lpt1
    int 21h

.fin:
    mov ah, 4Ch
    xor al, al
    int 21h
