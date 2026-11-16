# Laboratorio Práctico: Entrada y Salida Avanzados — Puertos, Polling e Interrupciones en NASM sobre DOSBox

**Asignatura:** Arquitectura de Computadores  
**Unidad 9:** Post-contenido (Laboratorio)  
**Estudiante:** Julián Andrés Ascanio  
**Repositorio:** `ascanio-post1-u9`  
**Herramientas:** DOSBox 0.74-3, Netwide Assembler (NASM)

---

## 1. Contexto y Objetivos

El presente laboratorio guiado implementa, en lenguaje ensamblador x86 de 16 bits (`.COM`, `ORG 0x100`) sobre DOSBox, los mecanismos avanzados de Entrada/Salida mediante acceso directo a puertos, sincronización por *polling* y atención de interrupciones hardware con el controlador PIC 8259A:

1. **Parte 1 (Acceso Directo a Puertos de E/S):**
   - `src/TECL.ASM`: Lectura de *scancode* desde el controlador de teclado 8042 (puertos `64h` y `60h`) mediante *polling* sobre el bit `OBF` (*Output Buffer Full*).
   - `src/POLL_T.ASM`: Implementación de *polling* con *timeout* configurable (`MAX_RETRY`) para evitar bloqueos indefinidos ante dispositivos sin respuesta.
   - `src/LPT1.ASM`: Escritura de un carácter al puerto paralelo LPT1 (`0378h`–`037Ah`) siguiendo el protocolo Centronics y generando el pulso `STROBE#`.
   - `src/MULTI_ST.ASM`: *Polling* combinado de dos puertos de estado (`64h` del teclado y `0379h` de LPT1) mediante `OR` a nivel de bit.

2. **Parte 2 (ISR Personalizado y Programación del PIC 8259A):**
   - `src/ISR_KB.ASM`: Instalación de una Rutina de Servicio de Interrupción (ISR) personalizada para `IRQ1` (`INT 09h`), lectura del puerto `60h`, envío de `EOI` al puerto `20h` y restauración del vector original.
   - `src/MASK_KB.ASM`: Enmascaramiento y desenmascaramiento temporal de `IRQ1` manipulando el bit 1 del registro `IMR` (`21h`) del PIC 8259A.
   - `src/ISR_CHAIN.ASM`: Encadenamiento (*chaining*) del ISR propio con el *handler* original mediante `PUSHF` y `CALL FAR [cs:old_isr]`, manteniendo el eco normal de DOS.
   - `src/ISR_TIME.ASM`: Medición del intervalo en *ticks* entre interrupciones consecutivas de `IRQ1` leyendo directamente el contador del BIOS en `0040h:006Ch`.

---

## 2. Estructura del Repositorio

```text
ascanio-post1-u9/
├── README.md          # Documentación técnica, tablas y cuatro decisiones justificadas
├── dosbox.conf        # Configuración de DOSBox y montaje automático de C:
├── .gitignore         # Exclusión de binarios externos (nasm.exe, debug.exe) y temporales
├── src/               # Código fuente NASM (16 bits, modo real)
│   ├── TECL.ASM
│   ├── POLL_T.ASM
│   ├── LPT1.ASM
│   ├── MULTI_ST.ASM
│   ├── ISR_KB.ASM
│   ├── MASK_KB.ASM
│   ├── ISR_CHAIN.ASM
│   └── ISR_TIME.ASM
├── bin/               # Ejecutables .COM ensamblados con NASM
│   ├── TECL.COM
│   ├── POLL_T.COM
│   ├── LPT1.COM
│   ├── MULTI_ST.COM
│   ├── ISR_KB.COM
│   ├── MASK_KB.COM
│   ├── ISR_CHAIN.COM
│   └── ISR_TIME.COM
└── capturas/          # Evidencias capturadas en DOSBox
```

---

## 3. Parte 1: Acceso Directo a Puertos de E/S

### 3.1 Puertos y Protocolos Utilizados
- **Controlador de teclado 8042 (`60h` / `64h`):** El puerto `64h` expone el *Status Register*, cuyo bit 0 (`OBF`) indica si hay un *scancode* disponible en el puerto de datos `60h`.
- **Puerto paralelo LPT1 (`0378h`–`037Ah`):** Al superar `FFh`, estos puertos de 16 bits se direccionan mediante `DX` (`IN AL, DX` / `OUT DX, AL`). El protocolo Centronics verifica `BUSY#=1` en el bit 7 de `0379h`, coloca el carácter en `0378h` y pulsa en bajo el bit 0 (`STROBE#`) del registro de control `037Ah`.
- **Polling combinado (`MULTI_ST.ASM`):** Aísla las banderas `OBF` (`BL`) y `BUSY#` (`BH`) y las combina con `OR AL, BH` para salir del bucle en cuanto cualquiera de los dos dispositivos esté listo, inspeccionando después `BL` y `BH` por separado.

### 3.2 Checkpoints de la Parte 1
| Checkpoint | Programa | Evidencia | Resultado Verificado en DOSBox |
| :--- | :--- | :--- | :--- |
| Compilación Parte 1 | `TECL`..`MULTI_ST` | [`CP1_compilacion_parte1.png`](capturas/CP1_compilacion_parte1.png) | Ensamblado sin errores con `nasm.exe` 0.98.38 (`4 File(s)` en `bin/`). |
| Checkpoint 1 | `TECL.COM` | [`CP2_tecl_scancode.png`](capturas/CP2_tecl_scancode.png) | Al presionar `'a'`, imprime `Scancode leido (hex): 1E`. |
| Checkpoint 2 | `POLL_T.COM` | [`CP3_poll_t_timeout.png`](capturas/CP3_poll_t_timeout.png) | Con `MAX_RETRY=0005h` sin tecla, muestra `Timeout: sin respuesta del dispositivo`. |
| Checkpoint 3 | `LPT1.COM` | [`CP4_lpt1_puerto_paralelo.png`](capturas/CP4_lpt1_puerto_paralelo.png) | Ejecuta el pulso `STROBE#` sobre `0378h`–`037Ah` sin bloqueo en DOSBox. |
| Checkpoint 4 | `MULTI_ST.COM` | [`CP5_multi_st_or.png`](capturas/CP5_multi_st_or.png) | Detecta e informa `LPT1 listo (BUSY#=1).` sin bloqueo al estar `BUSY#=1`. |
| Checkpoint 5 | `README.md` | Sección 3.3 | Dos decisiones técnicas justificadas de la Parte 1 (≥100 palabras cada una). |

### 3.3 Decisiones Técnicas de la Parte 1

#### Decisión Técnica 1: ¿Polling sin límite o polling con timeout configurable?
El bucle sin límite de `TECL.ASM` resulta aceptable únicamente en programas demostrativos o interactivos donde se garantiza que el dispositivo responderá, por ejemplo cuando el propio operador presiona una tecla frente a la consola. En cualquier aplicación real donde un periférico pueda estar desconectado, ocupado o averiado, es indispensable emplear un mecanismo de *timeout* como el de `POLL_T.ASM` para evitar que el sistema quede colgado indefinidamente en espera activa. No obstante, reducir `MAX_RETRY` a un valor demasiado pequeño (como `0005h` en lugar de `0FFFFh`) introduce el riesgo de generar falsos *timeouts* sobre dispositivos completamente funcionales cuya latencia de respuesta supera la duración de esas pocas iteraciones. Además, un contador `CX` en `LOOP` mide únicamente iteraciones del bucle y no tiempo real transcurrido: el tiempo efectivo de espera varía drásticamente según la frecuencia del procesador o los ciclos configurados en DOSBox (`cycles=20000`). Por ello, cuando se requiere una cota temporal precisa y portátil independientemente de la velocidad de la CPU, debe consultarse un reloj de tiempo real como el contador de *ticks* del sistema en `0040h:006Ch` utilizado en la Parte 2.

#### Decisión Técnica 2: ¿Combinar banderas de dos puertos con OR o verificarlas por separado?
Cuando en DOSBox el puerto paralelo LPT1 no tiene una impresora física conectada, su línea de estado `BUSY#` permanece constantemente en `1`. En esa situación, el bucle `.poll` de `MULTI_ST.ASM` evalúa `BL OR BH`, obtiene un resultado distinto de cero en la primera iteración y sale inmediatamente del bucle sin haber esperado realmente ningún evento del teclado. En la práctica, un dispositivo permanentemente «listo» anula la utilidad de la espera combinada para detectar el evento del segundo periférico. Asimismo, después de salir del bucle mediante `OR`, es obligatorio examinar `BL` y `BH` por separado porque la operación `OR` colapsa ambas condiciones en un único bit de resultado y descarta la identidad del puerto que disparó la salida. Si en lugar de `OR` se combinaran ambas banderas con `AND`, el programa exigiría que ambos dispositivos estuvieran listos de forma simultánea antes de continuar; esa variante sería apropiada para una sincronización tipo *rendezvous* —por ejemplo, esperar a que el usuario presione una tecla y que la impresora esté lista antes de transmitir un dato—, mientras que `OR` atiende al primero de los dos eventos.

---

## 4. Parte 2: ISR Personalizado y Programación del PIC 8259A

### 4.1 Vectores, IMR, EOI y Contador de Ticks
- **Instalación y restauración (`INT 21h`):** `AH=35h` obtiene el vector actual (`ES:BX`) de `INT 09h` (`IRQ1`), y `AH=25h` instala el nuevo *handler* (`DS:DX`). Al finalizar, se restaura el vector guardado bajo sección crítica (`CLI`/`STI`).
- **Enmascaramiento (`IMR` en puerto `21h`):** Poner a `1` el bit 1 (`02h`) deshabilita `IRQ1` en el PIC 8259A maestro sin afectar al temporizador `IRQ0` (`INT 1Ah` / `0040h:006Ch`), permitiendo medir ~3 segundos (55 *ticks*) antes de restaurar la máscara.
- **Encadenamiento (`ISR_CHAIN.ASM`):** Incrementa el contador propio sin consumir el puerto `60h` y delega mediante `PUSHF` + `CALL FAR [cs:old_isr]` para que el *handler* del BIOS procese la tecla y envíe el `EOI`.
- **Medición de intervalo (`ISR_TIME.ASM`):** Lee la palabra baja del contador de *ticks* del BIOS en `0040h:006Ch` (~18.2 *ticks*/s) y calcula `ticks_actual - ticks_prev` en cada evento `IRQ1`.

### 4.2 Checkpoints de la Parte 2
| Checkpoint | Programa | Evidencia | Resultado Verificado en DOSBox |
| :--- | :--- | :--- | :--- |
| Compilación Parte 2 | `ISR_KB`..`ISR_TIME` | [`CP6_compilacion_parte2.png`](capturas/CP6_compilacion_parte2.png) | Ensamblado sin errores con `nasm.exe` 0.98.38 (`4 File(s)` en `bin/`). |
| Checkpoint 1 | `ISR_KB.COM` | [`CP7_isr_kb_irq1.png`](capturas/CP7_isr_kb_irq1.png) | Captura 5 eventos `IRQ1` con el mensaje del ISR propio y restaura `INT 09h`. |
| Checkpoint 2 | `MASK_KB.COM` | [`CP8_mask_kb_imr.png`](capturas/CP8_mask_kb_imr.png) | Enmascara `IRQ1` durante ~55 *ticks* y muestra `IRQ1 restaurado.`. |
| Checkpoint 3 | `ISR_CHAIN.COM` | [`CP9_isr_chain.png`](capturas/CP9_isr_chain.png) | Conserva el eco normal de DOS (`abc`) y reporta los eventos `IRQ1` interceptados. |
| Checkpoint 4 | `ISR_TIME.COM` | [`CP10_isr_time_ticks.png`](capturas/CP10_isr_time_ticks.png) | Reporta los *ticks* transcurridos entre pulsaciones leyendo `0040h:006Ch`. |
| Checkpoint 5 | `README.md` | Sección 4.3 | Dos decisiones técnicas justificadas de la Parte 2 (≥100 palabras cada una). |

### 4.3 Decisiones Técnicas de la Parte 2

#### Decisión Técnica 3: ¿En qué punto del ISR debe ir el EOI?
Cuando el *End Of Interrupt* (`EOI`, valor `20h` al puerto `20h`) se retrasa hasta después de una operación lenta como imprimir una cadena mediante `INT 21h` —tal como ocurre en `ISR_KB.ASM`—, el controlador PIC 8259A mantiene bloqueado el despacho de todas las interrupciones de igual o menor prioridad durante esos milisegundos, incrementando la latencia del sistema. Dado que ninguno de los dos ISR del laboratorio ejecuta `STI` internamente, el procesador conserva `IF = 0` hasta el `IRET` final; por lo tanto, enviar el `EOI` de forma temprana (como hace `ISR_TIME.ASM` justo después de leer el puerto `60h` y el contador `0040h:006Ch`) no provoca la reentrada inmediata de `IRQ1` dentro del mismo ISR, sino que libera cuanto antes al PIC para que pueda preparar y despachar otras `IRQ` pendientes en cuanto el `IRET` habilite nuevamente las interrupciones. La práctica recomendada en programación de sistemas es enviar el `EOI` tan pronto como concluya la interacción crítica con el hardware —en este caso, vaciar el buffer del 8042 y registrar la marca de tiempo—, dejando tareas secundarias más largas para después, siempre garantizando que el estado del dispositivo ya haya sido atendido antes del `EOI`.

#### Decisión Técnica 4: ¿Polling o interrupción para el mismo dispositivo?
El bucle de *polling* de `TECL.ASM` consume el 100 % de los ciclos de CPU realizando lecturas repetidas sobre el puerto `64h` (*busy-wait*) mientras no exista un carácter disponible. Ese comportamiento resulta inaceptable en cualquier aplicación que deba realizar trabajo útil concurrente mientras espera al usuario, como un juego en modo texto, una animación gráfica o un programa DOS que atienda simultáneamente comunicaciones serie y teclado. En contraste, el enfoque basado en interrupciones de `ISR_KB.ASM` permite que el programa principal ejecute otras tareas y solo ceda el control cuando el controlador 8042 activa físicamente la línea `IRQ1`. Respecto a la latencia de reacción, el ISR responde de manera inmediata en cuanto el hardware señala la interrupción (al concluir la instrucción en curso), mientras que el *polling* queda supeditado al período con que el flujo del programa vuelva a ejecutar la comprobación `.poll`. Para un dispositivo lento y esporádico como el teclado, donde pueden transcurrir segundos o minutos entre pulsaciones, mantener la CPU bloqueada en espera activa desperdicia energía y tiempo de cómputo; el *polling* debe reservarse únicamente para esperas breves de microsegundos donde instalar un ISR no se justifica.

---

## 5. Compilación y Ejecución en DOSBox

Desde la raíz del repositorio montada como unidad `C:` en DOSBox:

```bat
nasm -f bin src\TECL.ASM      -o bin\TECL.COM
nasm -f bin src\POLL_T.ASM    -o bin\POLL_T.COM
nasm -f bin src\LPT1.ASM      -o bin\LPT1.COM
nasm -f bin src\MULTI_ST.ASM  -o bin\MULTI_ST.COM
nasm -f bin src\ISR_KB.ASM    -o bin\ISR_KB.COM
nasm -f bin src\MASK_KB.ASM   -o bin\MASK_KB.COM
nasm -f bin src\ISR_CHAIN.ASM -o bin\ISR_CHAIN.COM
nasm -f bin src\ISR_TIME.ASM  -o bin\ISR_TIME.COM
```
