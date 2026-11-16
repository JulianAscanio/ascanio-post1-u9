; ISR_TIME.ASM - Medicion de intervalo entre interrupciones IRQ1 (0040h:006Ch)
; Compilar: nasm -f bin src\ISR_TIME.ASM -o bin\ISR_TIME.COM
[BITS 16]
[ORG 0x100]

PIC_EOI_PORT    EQU 20h
PIC_EOI_CMD     EQU 20h
KB_DATA_PORT    EQU 60h
BIOS_DATA_SEG   EQU 0040h
BIOS_TICKS_OFF  EQU 006Ch
MAX_KEYS        EQU 5

section .data
    old_isr     dd 0
    ticks_prev  dw 0
    contador    dw 0
    msg_inicio  db "ISR_TIME activo. Presione teclas para medir ticks (5 eventos)...$"
    msg_ticks   db 0Dh, 0Ah, "Ticks desde la interrupcion anterior: $"
    msg_fin     db 0Dh, 0Ah, "ISR_TIME restaurado. Fin del programa.", 0Dh, 0Ah, "$"

section .text
start:
    ; Guardar vector original INT 09h
    mov ax, 3509h
    int 21h
    mov [old_isr], bx
    mov [old_isr + 2], es

    ; Inicializar ticks_prev con la lectura actual en 0040h:006Ch
    push es
    mov ax, BIOS_DATA_SEG
    mov es, ax
    mov ax, [es:BIOS_TICKS_OFF]
    mov [ticks_prev], ax
    pop es

    mov ah, 09h
    mov dx, msg_inicio
    int 21h

    ; Instalar ISR propio
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

    ; Restaurar handler original
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

; ── ISR propio con medicion de ticks ────────────────────────────────────────
mi_isr:
    push ax
    push bx
    push dx
    push ds
    push es

    mov ax, cs
    mov ds, ax

    ; Leer y descartar scancode del 8042
    in  al, KB_DATA_PORT

    ; Leer contador de ticks del BIOS en 0040h:006Ch
    mov ax, BIOS_DATA_SEG
    mov es, ax
    mov ax, [es:BIOS_TICKS_OFF]
    mov bx, ax
    sub bx, [ticks_prev]
    mov [ticks_prev], ax

    ; Enviar EOI temprano al PIC antes de imprimir por consola
    mov al, PIC_EOI_CMD
    out PIC_EOI_PORT, al

    ; Imprimir ticks transcurridos
    mov ah, 09h
    mov dx, msg_ticks
    int 21h
    mov ax, bx
    call imprimir_decimal

    inc word [contador]

    pop es
    pop ds
    pop dx
    pop bx
    pop ax
    iret

; ── Subrutina: imprime AX en decimal (sin signo) ────────────────────────────
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
