; MASK_KB.ASM - Enmascaramiento y desenmascaramiento de IRQ1 con el PIC 8259A
; Compilar: nasm -f bin src\MASK_KB.ASM -o bin\MASK_KB.COM
[BITS 16]
[ORG 0x100]

PIC_IMR_PORT    EQU 21h
IRQ1_MASK_BIT   EQU 02h             ; bit 1 corresponde a IRQ1 (teclado)
WAIT_TICKS      EQU 55              ; ~3 segundos (18.2 ticks/s * 3)

section .data
    msg_mask    db "IRQ1 enmascarado (teclado deshabilitado ~3s)...$"
    msg_unmask  db 0Dh, 0Ah, "IRQ1 restaurado.", 0Dh, 0Ah, "$"

section .text
start:
    ; Leer IMR actual y preservarlo en la pila
    in  al, PIC_IMR_PORT
    push ax

    ; Enmascarar IRQ1 (poner bit 1 en 1)
    or  al, IRQ1_MASK_BIT
    out PIC_IMR_PORT, al

    mov ah, 09h
    mov dx, msg_mask
    int 21h

    ; Esperar ~3 segundos leyendo el contador de ticks via INT 1Ah
    mov ah, 00h
    int 1Ah                         ; CX:DX = ticks actuales
    mov bx, dx
    add bx, WAIT_TICKS

.wait:
    mov ah, 00h
    int 1Ah
    cmp dx, bx
    jl  .wait

    ; Restaurar IMR original
    pop ax
    out PIC_IMR_PORT, al

    mov ah, 09h
    mov dx, msg_unmask
    int 21h

    mov ah, 4Ch
    xor al, al
    int 21h
