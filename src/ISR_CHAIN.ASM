; ISR_CHAIN.ASM - Encadenamiento de ISR propio con el handler original de INT 09h
; Compilar: nasm -f bin src\ISR_CHAIN.ASM -o bin\ISR_CHAIN.COM
[BITS 16]
[ORG 0x100]

MAX_CHARS       EQU 3

section .data
    contador    dw 0
    old_isr     dd 0                ; SEG:OFF del handler original
    msg_inicio  db "ISR_CHAIN activo. Escriba 3 caracteres (eco DOS normal): $"
    msg_count   db 0Dh, 0Ah, "Eventos IRQ1 interceptados antes de encadenar: $"
    msg_fin     db 0Dh, 0Ah, "Handler original restaurado.", 0Dh, 0Ah, "$"

section .text
start:
    ; Guardar vector original de INT 09h
    mov ax, 3509h
    int 21h
    mov [old_isr], bx
    mov [old_isr + 2], es

    mov ah, 09h
    mov dx, msg_inicio
    int 21h

    ; Instalar ISR encadenado
    push ds
    mov ax, cs
    mov ds, ax
    mov dx, mi_isr_chain
    mov ax, 2509h
    int 21h
    pop ds

    ; Leer 3 caracteres usando DOS (demuestra que el handler original sigue operando)
    mov cx, MAX_CHARS
.leer:
    mov ah, 01h
    int 21h
    loop .leer

    ; Restaurar vector original
    cli
    lds dx, [old_isr]
    mov ax, 2509h
    int 21h
    sti

    mov ax, cs
    mov ds, ax
    mov ah, 09h
    mov dx, msg_count
    int 21h

    mov ax, [contador]
    call imprimir_decimal

    mov ah, 09h
    mov dx, msg_fin
    int 21h

    mov ah, 4Ch
    xor al, al
    int 21h

; ── ISR encadenado: cuenta la IRQ1 y delega al handler original ─────────────
mi_isr_chain:
    inc word [cs:contador]
    pushf
    call far [cs:old_isr]           ; el handler original lee 60h y envia EOI
    iret

; ── Subrutina: imprime AX en decimal ────────────────────────────────────────
imprimir_decimal:
    push ax
    push bx
    push cx
    push dx
    mov bx, 10
    xor cx, cx
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
.imprimir:
    pop dx
    add dl, 30h
    mov ah, 02h
    int 21h
    loop .imprimir
    pop dx
    pop cx
    pop bx
    pop ax
    ret
