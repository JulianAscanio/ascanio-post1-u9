; ISR_KB.ASM - ISR personalizado para IRQ1 (teclado, INT 09h)
; Compilar: nasm -f bin src\ISR_KB.ASM -o bin\ISR_KB.COM
[BITS 16]
[ORG 0x100]

PIC_EOI_PORT    EQU 20h
PIC_EOI_CMD     EQU 20h
KB_DATA_PORT    EQU 60h
MAX_KEYS        EQU 5

section .data
    contador    dw 0
    old_isr     dd 0                ; SEG:OFF del handler original de INT 09h
    msg_inicio  db "ISR_KB activo. Presione teclas (5 eventos IRQ1)...$"
    msg_tecla   db 0Dh, 0Ah, "Tecla detectada por ISR propio$"
    msg_fin     db 0Dh, 0Ah, "ISR restaurado. Fin del programa.", 0Dh, 0Ah, "$"

section .text
start:
    ; Guardar vector original INT 09h (ES:BX)
    mov ax, 3509h
    int 21h
    mov [old_isr], bx
    mov [old_isr + 2], es

    mov ah, 09h
    mov dx, msg_inicio
    int 21h

    ; Instalar ISR propio en INT 09h
    push ds
    mov ax, cs
    mov ds, ax
    mov dx, mi_isr
    mov ax, 2509h
    int 21h
    pop ds

    sti

.esperar:
    mov ax, [contador]
    cmp ax, MAX_KEYS
    jl  .esperar

    ; Restaurar handler original de INT 09h
    cli
    lds dx, [old_isr]
    mov ax, 2509h
    int 21h
    sti

    mov ax, cs
    mov ds, ax
    mov ah, 09h
    mov dx, msg_fin
    int 21h

    mov ah, 4Ch
    xor al, al
    int 21h

; ── ISR propio para IRQ1 ────────────────────────────────────────────────────
mi_isr:
    push ax
    push dx
    push ds

    mov ax, cs
    mov ds, ax

    ; Leer y descartar el scancode del 8042 para liberar el buffer
    in  al, KB_DATA_PORT

    ; Mostrar mensaje de deteccion
    mov ah, 09h
    mov dx, msg_tecla
    int 21h

    inc word [contador]

    ; Enviar EOI al PIC maestro (puerto 20h)
    mov al, PIC_EOI_CMD
    out PIC_EOI_PORT, al

    pop ds
    pop dx
    pop ax
    iret
