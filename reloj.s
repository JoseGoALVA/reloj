; Archivo:	main.s
; Dispositivo:	PIC16F887
; Autor:	Jose Gonzalez
; Compilador:	pic-as (v2.35), MPLABX V6.00
;                
; Programa:	TMR0 y contador en PORTC con 5 displays hexadecimales y deciamles
; Hardware:	Displays en el PORTC, transistores 2n2222 en el PORTD, push buttons y resitencias	
;
; Creado:	25 de feb 2022
; Última modificación: 26 feb 2022
    
PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF               ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR21V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
  
#include <xc.inc>
  
  BMODO EQU 0
  BAUMENTO EQU 1
  BDECREMENTO EQU 2
  BEDITAR EQU 3
  BELECCION EQU 4
 
 
; -------------- MACROS --------------- 
  ; Macro para reiniciar el valor del TMR0
  ; **Recibe el valor a configurar en TMR_VAR**
  RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
    
    RESET_TMR1 MACRO TMR1_H, TMR1_L	 ; Esta es la forma correcta
    BANKSEL TMR1H
    MOVLW   TMR1_H	    ; Literal a guardar en TMR1H
    MOVWF   TMR1H	    ; Guardamos literal en TMR1H
    MOVLW   TMR1_L	    ; Literal a guardar en TMR1L
    MOVWF   TMR1L	    ; Guardamos literal en TMR1L
    BCF	    TMR1IF	    ; Limpiamos bandera de int. TMR1
    ENDM
    
    TABLA_DISPLAYS  MACRO VAR1, VAR2, VAR3, VAR4
    MOVF    VAR1, W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   HORAS2		; Guardamos en display
    
    MOVF    VAR2, W		; Movemos nibble alto a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   HORAS1		; Guardamos en display+1
  		
    MOVF    VAR3, W		; Movemos cent a W
    CALL    TABLA_7SEG		; Buscamos W en la tabla hexadecimal
    MOVWF   MINUTOS2		; Movemos cent a centenas
    
    MOVF    VAR4, W		; Movemos cent a W
    CALL    TABLA_7SEG		; Buscamos W en la tabla hexadecimal    
    MOVWF   MINUTOS1		; Movemos dece a decenas 
    ENDM
  
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
W_TEMP:		DS 1
STATUS_TEMP:	DS 1
MINUTOS:	DS 6
SEGU:		DS 1
    
PSECT udata_bank0
valor:		DS 1	; Contiene valor a mostrar en los displays de 7-seg
banderas:	DS 1	; Indica que display hay que encender
nibbles:	DS 2	; Contiene los nibbles alto y bajo de valor
display:	DS 6	; Representación de cada nibble en el display de 7-seg
MINUTOS1:	DS 1	; Contador de decenas
MINUTOS2:	DS 1
MIN:		DS 1    ; CHEQUEA QUE SE LLEGUE A 60 SEGUNDOS
MIN2:		DS 1    ; CHEQUEA QUE SE LLEGUE A 60 SEGUNDOS
HOR1:		DS 1
HOR2:		DS 1
HORAS2:		DS 1
HORAS1:		DS 1
chequeo_underflow1:	DS 1
chequeo_underflow2:	DS 1
Achequeo_underflow1:	DS 1
Achequeo_underflow2:	DS 1
BANDERAS:		DS 1
TIMER_SEGUNDOS1: DS 1
TIMER_SEGUNDOS2: DS 1
TIMER_MINUTOS1: DS 1
TIMER_MINUTOS2: DS 1
LUZ:		DS 1
chequeo_19:	DS 1    
Achequeo_19:	DS 1    
BANDERA_T:	DS 1
P_SEGUIR:	DS 1
DECREMENTAR:	DS 1
FRENO:		DS 1
AFRENO:		DS 1
HORA_19:	DS 1
MES1:		DS 1
MES2:		DS 1
DIAS1:		DS 1
DIAS2:		DS 1
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN		; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
PUSH:
    MOVWF   W_TEMP		; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP		; Guardamos STATUS
    
ISR:
    BTFSC   T0IF		; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0		; Si -> Subrutina de interrupción de TMR0
    
    BTFSC   RBIF		; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_PORTB		; Si -> Subrutina de interrupción de PORTB
    
    BTFSC   TMR1IF		; Interrupcion de TMR1?
    CALL    INT_TMR1
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS		; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W		; Recuperamos valor de W
    RETFIE			; Regresamos a ciclo principal

;--------------------------------------    

INT_TMR0:
    RESET_TMR0 251		; Reiniciamos TMR0 para 50ms
    CALL    MOSTRAR_VALOR	; Mostramos valor en hexadecimal en los displays
    INCF    LUZ
    RETURN
    
INT_PORTB:
    BTFSS   BANDERAS, 0		; Verificamos en que estado estamos (S1 o S2)
    GOTO    ESTADO_0
    BTFSC   BANDERAS, 1
    GOTO    ESTADO_1
    BTFSC   BANDERAS, 2
    GOTO    ESTADO_2
    RETURN

INT_TMR1:
    RESET_TMR1 0xF3, 0xCB   ; Reiniciamos TMR1 para 1s
    INCF    SEGU
    RETURN	
    

PSECT code, delta=2, abs
ORG 100h			; posición 100h para el codigo
;------------- CONFIGURACION ------------
MAIN:
    CALL    CONFIG_IO		; Configuración de I/O
    CALL    CONFIG_RELOJ	; Configuración de Oscilador
    CALL    CONFIG_TMR0		; Configuración de TMR0
    CALL    CONFIG_TMR1		; Configuración de TMR0
    CALL    CONFIG_INT		; Configuración de interrupciones
    
LOOP:
    MOVF    MIN, W		; Valor del PORTA a W
    MOVWF   valor		; Movemos W a variable valor
    CALL    OBTENER_NIBBLE	; Guardamos nibble alto y bajo de valor
    CALL    SET_DISPLAY		; Guardamos los valores a enviar en PORTC para mostrar valor en hex  
    CALL    SEGUNDOS60  
    CALL    LUCES
    GOTO    LOOP		; Regresamos al LOOP
    
;----------------- LUCES ----------------------
LUCES:
    MOVLW   50
    SUBWF   LUZ, W
    BTFSC   STATUS, 2
    BSF	    PORTA, 0
    CLRF    STATUS
    
    MOVLW   100
    SUBWF   LUZ, W
    BTFSC   STATUS, 2
    BCF	    PORTA, 0
    BTFSC   STATUS, 2
    CLRF    LUZ
    RETURN
    
; ----------------CHEQUEO DE SEGUNDOS----------**
    
ESTADO_0:
    BTFSC   PORTB, BMODO		; Si se presionó botón de cambio de modo
    BSF	    BANDERAS, 0		
    BTFSC   PORTB, BMODO
    BSF	    BANDERAS, 1
    
    
    BCF	    BANDERA_T, 1
    BCF	    BANDERA_T, 0
     
    BSF	    PORTA, 1
    BCF	    PORTA, 2
    
    BTFSC   FRENO, 0
    CALL    PARAR
    BTFSS   FRENO, 0
    CALL    SEGUIR
    
    BCF	    RBIF			; Limpiamos bandera de interrupción
    RETURN
    
ESTADO_1:
    BTFSC   PORTB, BMODO		; Si se presionó botón de cambio de modo
    BCF	    BANDERAS, 1		
    BTFSC   PORTB, BMODO
    BSF	    BANDERAS, 2		; Limpiamos bandera de interrupción
    
    BSF	    BANDERA_T, 1
    BSF	    BANDERA_T, 0
    
    BCF	    PORTA, 1
    BSF	    PORTA, 2
    
    BTFSS   DECREMENTAR, 0
    CALL    APARAR
    BTFSC   DECREMENTAR, 0
    CALL    ASEGUIR
 
    BCF	    RBIF
    RETURN
    
ESTADO_2:
    BTFSC   PORTB, BMODO		; Si se presionó botón de cambio de modo
    BCF	    BANDERAS, 2		
    BTFSC   PORTB, BMODO
    BCF	    BANDERAS, 0			; Limpiamos bandera de interrupción
    
    BSF	    BANDERA_T, 1
    BSF	    BANDERA_T, 0
    
    BSF	    PORTA, 1
    BSF	    PORTA, 2
 
    BCF	    RBIF
    RETURN
    
SEGUNDOS60:
    MOVLW   1
    SUBWF   SEGU, W
    BTFSC   STATUS, 2
    CALL    MINUTOS60_1
    RETURN 
    
MINUTOS60_1:
    CLRF    SEGU
    CLRF    STATUS
    BTFSS   PORTD, 5
    INCF    MIN
    
    MOVLW   10
    SUBWF   MIN, W
    BTFSC   STATUS, 2
    CALL    MINUTOS60_2
    RETURN
    
MINUTOS60_2:
    CLRF    MIN
    CLRF    STATUS
    INCF    MIN2
    
    MOVLW   6
    SUBWF   MIN2, W
    BTFSC   STATUS, 2
    CALL    HORAS24_1
    RETURN
    
HORAS24_1:
    CLRF    MIN2
    CLRF    STATUS
    INCF    HOR1
    
    CALL CHEQUEARH 
    
    BTFSS   HORA_19, 0
    MOVLW   10
    BTFSC   HORA_19, 0
    MOVLW   5   
    
    SUBWF   HOR1, W
    BTFSC   STATUS, 2
    CALL    HORAS24_2
    RETURN
    
CHEQUEARH:
    MOVLW   2
    XORWF   HOR2, W
    BTFSS   STATUS, 2
    BCF	    HORA_19, 0
    BTFSS   STATUS, 2
    RETURN
    
    MOVLW   3
    XORWF   HOR1, W
    BTFSC   STATUS, 2
    BSF	    HORA_19, 0
    RETURN
    
HORAS24_2:
    CLRF    HOR1
    CLRF    STATUS
    INCF    HOR2
    
    MOVLW   3
    SUBWF   HOR2, W
    BTFSC   STATUS, 2
    CLRF    HOR2
    RETURN
    
;------------- SUBRUTINAS ---------------
CONFIG_RELOJ:
    BANKSEL OSCCON	    ; cambiamos a banco 1
    BSF	    OSCCON, 0	    ; SCS -> 1, Usamos reloj interno
    BCF	    IRCF2
    BSF	    IRCF1
    BSF	    IRCF0	    ; IRCF<2:0> -> 101 500KHZ
    RETURN
    
; Configuramos el TMR0 para obtener un retardo de 50ms
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    T0CS		; TMR0 como temporizador
    BCF	    PSA			; prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0			; PS<2:0> -> 111 prescaler 1 : 256
    RESET_TMR0 251		; Reiniciamos TMR0 para 50ms
    RETURN 
    
CONFIG_IO:
    
    CLRF    MIN	
    CLRF    MIN2	
    CLRF    HOR1	
    CLRF    HOR2	
    CLRF    W_TEMP		
    CLRF    STATUS_TEMP	
    CLRF    MINUTOS
    CLRF    SEGU
    CLRF    valor
    CLRF    banderas
    CLRF    MINUTOS1
    CLRF    MINUTOS2
    CLRF    HORAS2
    CLRF    HORAS1
    CLRF    chequeo_underflow1
    CLRF    chequeo_underflow2
    CLRF    Achequeo_underflow1
    CLRF    Achequeo_underflow2
    CLRF    BANDERAS
    CLRF    TIMER_SEGUNDOS1
    CLRF    TIMER_SEGUNDOS2
    CLRF    TIMER_MINUTOS1
    CLRF    TIMER_MINUTOS2
    CLRF    LUZ
    CLRF    chequeo_19
    CLRF    Achequeo_19
    CLRF    BANDERA_T
    CLRF    P_SEGUIR
    CLRF    DECREMENTAR
    CLRF    FRENO
    CLRF    AFRENO
    CLRF banderas
    
    CLRF    BANDERAS		; Limpiamos GPR
    CLRF    STATUS
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH		; I/O digitales
    
    BANKSEL TRISC
    CLRF    TRISC		; PORTC como salida
    CLRF    TRISD
    BSF	    TRISB, BMODO	; RB0 como entrada / Botón modo
    BSF	    TRISB, BAUMENTO	; RB1 como entrada / Botón acción
    BSF	    TRISB, BDECREMENTO		; RB1 como entrada / Botón acción
    BSF	    TRISB, BEDITAR
    BSF	    TRISB, BELECCION
    CLRF    TRISA		; RBA como salida
    
    BANKSEL PORTC
    CLRF    PORTC		; Apagamos PORTC
    CLRF    PORTD
    CLRF    PORTA
    CLRF    PORTB

    
    RETURN
    
CONFIG_INT:
    BANKSEL IOCB		
    BSF	    IOCB0		; Habilitamos int. por cambio de estado en RB0
    BSF	    IOCB1		; Habilitamos int. por cambio de estado en RB7
    BSF	    IOCB2		; Habilitamos int. por cambio de estado en RB7
    BSF	    IOCB3		; Habilitamos int. por cambio de estado en RB7
    BSF	    IOCB4		; Habilitamos int. por cambio de estado en RB7
    
    BANKSEL INTCON
    BSF	    GIE			; Habilitamos interrupciones
    BSF	    T0IE		; Habilitamos interrupcion TMR0
    BSF	    RBIE
    BCF	    T0IF		; Limpiamos bandera de int. de TMR0
    BCF	    RBIF		; Limpiamos bandera de int. de PORTB
    BCF	    TMR1IF		 ; Limpiamos bandera de TMR1
	
    BANKSEL PIE1	    ; Cambiamos a banco 01
    BSF	    TMR1IE	    ; Habilitamos int. TMR1
    
    RETURN
    
PARAR:
    BTFSC   PORTB, BEDITAR
    BCF	    FRENO, 0
    BCF	    TMR1ON
    BCF	    RBIF
    CALL    DA_MH
    RETURN
	
ACEPTAR:
    BTFSC   PORTB, BEDITAR		; Si se presionó botón de cambio de modo
    BSF	    PORTD, 5		; Pasar a S1		
    BCF	    RBIF
    RETURN
    
EDITAR:
    BTFSC   PORTB, BEDITAR		; Si se presionó botón de cambio de modo
    BCF	    PORTD, 5		; Pasar a S0
	
    CALL    DA_MH
    BCF	    RBIF
    RETURN
	
DA_MH:
    BTFSS   PORTD, 6		; Verificamos en que estado estamos (S1 o S2)
    GOTO    D_MINUTOS
    BTFSC   PORTD, 6
    GOTO    D_HORAS
    RETURN
    
D_MINUTOS:
    BTFSC   PORTB, BELECCION		; Si se presionó botón de cambio de modo
    BSF	    PORTD, 6
    BCF	    RBIF
	
    BTFSC	PORTB, BAUMENTO
    INCF	MIN
    BTFSC	PORTB, BAUMENTO
    CALL	IMINUTOS60_1
    BTFSC	PORTB, BDECREMENTO
    DECF	MIN
    CALL	UNDERFLOW_MINUTOS
	
    MOVLW	1
    SUBWF	chequeo_underflow1, W
    BTFSC	STATUS, 2
    CALL	DECREMENTO_RELOJ 
    CLRF	STATUS
    BCF		RBIF
    RETURN
	
IMINUTOS60_1:
    CLRF    STATUS
    BTFSS   PORTD, 5
    
    MOVLW   10
    SUBWF   MIN, W
    BTFSC   STATUS, 2
    CALL    IMINUTOS60_2
    RETURN
    
IMINUTOS60_2:
    CLRF    MIN
    CLRF    STATUS
    INCF    MIN2
    
    MOVLW   6
    SUBWF   MIN2, W
    BTFSC   STATUS, 2
    CLRF    MIN2
    RETURN
    
UNDERFLOW_MINUTOS:
    MOVLW	0
    XORWF	MIN2, W
    BTFSS	STATUS, 2
    RETURN

    MOVLW	255
    XORWF	MIN, W
    BTFSC	STATUS, 2
    CALL	CERO
	
    RETURN
	
CERO:
    CLRF    MIN		; Limpiamos la variable cent
    MOVLW   9			; Movemos el valor literal 100 a W
    SUBWF   MIN, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    MIN		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
    
    CLRF    MIN2		; Limpiamos la variable cent
    MOVLW   5			; Movemos el valor literal 100 a W
    SUBWF   MIN2, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    MIN2		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
	
    INCF	chequeo_underflow1
	
    RETURN
	
DECREMENTO_RELOJ:
    MOVLW	255
    XORWF	MIN, W
    BTFSC	STATUS, 2
    CALL	UMINUTOS60_1
    RETURN 
    
UMINUTOS60_1:	
    CLRF    MIN		; Limpiamos la variable cent
    MOVLW   9			; Movemos el valor literal 100 a W
    SUBWF   MIN, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    MIN		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
    
    DECF	MIN2
    CALL	TODO_CERO_M
    RETURN
    
TODO_CERO_M:
    MOVLW	0
    XORWF	MIN2, W
    BTFSS	STATUS, 2
    RETURN
	
    MOVLW	1
    XORWF	MIN, W
    BTFSC	STATUS, 2
    DECF	chequeo_underflow1
    RETURN
	
D_HORAS:
    BTFSC   PORTB, BELECCION		; Si se presionó botón de cambio de modo
    BCF	PORTD, 6
    BCF	RBIF
	
    BTFSC	PORTB, BAUMENTO
    INCF	HOR1
    BTFSC	PORTB, BAUMENTO
    CALL	IHORAS_1
    BTFSC	PORTB, BDECREMENTO
    DECF	HOR1
    CALL	UNDERFLOW_HORAS
	
    MOVLW	1
    SUBWF	chequeo_underflow2, W
    BTFSC	STATUS, 2
    CALL	DECREMENTO_RELOJ_H 
    CLRF	STATUS
    BCF		RBIF
    RETURN
	
IHORAS_1:
    BCF	    chequeo_19, 0
    
    BTFSS   chequeo_19, 0
    MOVLW   10
    BTFSC   chequeo_19, 0
    MOVLW   5
    
    SUBWF   HOR1, W
    BTFSC   STATUS, 2
    CALL    IHORAS_2
    RETURN
    
    
    
IHORAS_2:
    CLRF    HOR1
    CLRF    STATUS
    INCF    HOR2
    CALL    CHEQUEO_HORAS
    
    MOVLW   3
    SUBWF   HOR2, W
    BTFSC   STATUS, 2
    CLRF    HOR2
    
    
    RETURN
    
CHEQUEO_HORAS:
    MOVLW   2
    SUBWF   HOR2, W
    BTFSS   STATUS, 2
    BSF    chequeo_19, 0
    RETURN
    
UNDERFLOW_HORAS:
    MOVLW	0
    XORWF	HOR2, W
    BTFSS	STATUS, 2
    RETURN

    MOVLW	255
    XORWF	HOR1, W
    BTFSC	STATUS, 2
    CALL	CERO_H
	
    RETURN
	
CERO_H:
    CLRF    HOR1		; Limpiamos la variable cent
    MOVLW   4			; Movemos el valor literal 100 a W
    SUBWF   HOR1, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    HOR1		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
    
    CLRF    HOR2		; Limpiamos la variable cent
    MOVLW   2			; Movemos el valor literal 100 a W
    SUBWF   HOR2, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    HOR2		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
	
    INCF    chequeo_underflow2
    CLRF    STATUS
	
    RETURN
	
DECREMENTO_RELOJ_H:
    MOVLW	255
    XORWF	HOR1, W
    BTFSC	STATUS, 2
    CALL	UHORAS_1
    RETURN 
    
UHORAS_1:	
    CLRF    HOR1		; Limpiamos la variable cent
    MOVLW   9			; Movemos el valor literal 100 a W
    SUBWF   HOR1, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    HOR1		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
    
    DECF    HOR2
    CALL    TODO_CERO_H
    RETURN
    
    TODO_CERO_H:
    MOVLW	0
    XORWF	HOR2, W
    BTFSS	STATUS, 2
    RETURN
	
    MOVLW	1
    XORWF	HOR1, W
    BTFSC	STATUS, 2
    DECF	chequeo_underflow2
    RETURN
    
SEGUIR:
    BTFSC   PORTB, BAUMENTO
    BSF	    FRENO, 0
    BSF	    TMR1ON
    RETURN
	
; --------------------------------------

APARAR:
    
    BTFSC   PORTB, BEDITAR
    BSF	    DECREMENTAR, 0
    
    BCF	    TMR1ON
    BCF	    RBIF
    CALL    AD_MH
    RETURN
	
AD_MH:
    BTFSS   PORTD, 6		; Verificamos en que estado estamos (S1 o S2)
    GOTO    AD_MINUTOS
    BTFSC   PORTD, 6
    GOTO    AD_HORAS
    RETURN
    
AD_MINUTOS:
    BTFSC   PORTB, BELECCION		; Si se presionó botón de cambio de modo
    BSF	    PORTD, 6
    BCF	    RBIF
	
    BTFSC	PORTB, BAUMENTO
    INCF	TIMER_SEGUNDOS1
    BTFSC	PORTB, BAUMENTO
    CALL	AIMINUTOS60_1
    BTFSC	PORTB, BDECREMENTO
    DECF	TIMER_SEGUNDOS1
    CALL	AUNDERFLOW_MINUTOS
	
    MOVLW	1
    SUBWF	Achequeo_underflow1, W
    BTFSC	STATUS, 2
    CALL	ADECREMENTO_RELOJ 
    CLRF	STATUS
    BCF		RBIF
    RETURN
	
AIMINUTOS60_1:
    CLRF    STATUS
    
    MOVLW   10
    SUBWF   TIMER_SEGUNDOS1, W
    BTFSC   STATUS, 2
    CALL    AIMINUTOS60_2
    RETURN
    
AIMINUTOS60_2:
    CLRF    TIMER_SEGUNDOS1
    CLRF    STATUS
    INCF    TIMER_SEGUNDOS2
    
    MOVLW   10
    SUBWF   TIMER_SEGUNDOS2, W
    BTFSC   STATUS, 2
    CLRF    TIMER_SEGUNDOS2
    RETURN
    
AUNDERFLOW_MINUTOS:
    MOVLW	0
    XORWF	TIMER_SEGUNDOS2, W
    BTFSS	STATUS, 2
    RETURN

    MOVLW	255
    XORWF	TIMER_SEGUNDOS1, W
    BTFSC	STATUS, 2
    CALL	ACERO
	
    RETURN
	
ACERO:
    CLRF    TIMER_SEGUNDOS1		; Limpiamos la variable cent
    MOVLW   9			; Movemos el valor literal 100 a W
    SUBWF   TIMER_SEGUNDOS1, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    TIMER_SEGUNDOS1		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
    
    CLRF    TIMER_SEGUNDOS2		; Limpiamos la variable cent
    MOVLW   5			; Movemos el valor literal 100 a W
    SUBWF   TIMER_SEGUNDOS2, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    TIMER_SEGUNDOS2		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
	
    INCF	Achequeo_underflow1
	
    RETURN
	
ADECREMENTO_RELOJ:
    MOVLW	255
    XORWF	TIMER_SEGUNDOS1, W
    BTFSC	STATUS, 2
    CALL	AUMINUTOS60_1
    RETURN 
    
AUMINUTOS60_1:	
    CLRF    TIMER_SEGUNDOS1		; Limpiamos la variable cent
    MOVLW   9			; Movemos el valor literal 100 a W
    SUBWF   TIMER_SEGUNDOS1, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    TIMER_SEGUNDOS1		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
    
    DECF	TIMER_SEGUNDOS2
    CALL	ATODO_CERO_M
    RETURN
    
ATODO_CERO_M:
    MOVLW	0
    XORWF	TIMER_SEGUNDOS2, W
    BTFSS	STATUS, 2
    RETURN
	
    MOVLW	1
    XORWF	TIMER_SEGUNDOS1, W
    BTFSC	STATUS, 2
    DECF	Achequeo_underflow1
    RETURN
	
AD_HORAS:
    BTFSC   PORTB, BELECCION		; Si se presionó botón de cambio de modo
    BCF	    PORTD, 6
    BCF	    RBIF
	
    BTFSC	PORTB, BAUMENTO
    INCF	TIMER_MINUTOS1
    BTFSC	PORTB, BAUMENTO
    CALL	AIHORAS_1
    BTFSC	PORTB, BDECREMENTO
    DECF	TIMER_MINUTOS1
    CALL	AUNDERFLOW_HORAS
	
    MOVLW	1
    SUBWF	Achequeo_underflow2, W
    BTFSC	STATUS, 2
    CALL	ADECREMENTO_RELOJ_H 
    CLRF	STATUS
    BCF		RBIF
    RETURN
	
AIHORAS_1:
    MOVLW   10

    
    SUBWF   TIMER_MINUTOS1, W
    BTFSC   STATUS, 2
    CALL    AIHORAS_2
    RETURN
    
    
    
AIHORAS_2:
    CLRF    TIMER_MINUTOS1
    CLRF    STATUS
    INCF    TIMER_MINUTOS2
    CALL    ACHEQUEO_HORAS
    
    MOVLW   10
    SUBWF   TIMER_MINUTOS2, W
    BTFSC   STATUS, 2
    CLRF    TIMER_MINUTOS2
    
    
    RETURN
    
ACHEQUEO_HORAS:
    MOVLW   10
    SUBWF   TIMER_MINUTOS2, W
    BTFSS   STATUS, 2
    BSF	    Achequeo_19, 0
    RETURN
    
AUNDERFLOW_HORAS:
    MOVLW	0
    XORWF	TIMER_MINUTOS2, W
    BTFSS	STATUS, 2
    RETURN

    MOVLW	255
    XORWF	TIMER_MINUTOS1, W
    BTFSC	STATUS, 2
    CALL	ACERO_H
	
    RETURN
	
ACERO_H:
    CLRF    TIMER_MINUTOS1		; Limpiamos la variable cent
    MOVLW   10			; Movemos el valor literal 100 a W
    SUBWF   TIMER_MINUTOS1, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    TIMER_MINUTOS1		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
    
    CLRF    TIMER_MINUTOS2		; Limpiamos la variable cent
    MOVLW   10			; Movemos el valor literal 100 a W
    SUBWF   TIMER_MINUTOS2, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    TIMER_MINUTOS2		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
	
    INCF    Achequeo_underflow2
    CLRF    STATUS
	
    RETURN
	
ADECREMENTO_RELOJ_H:
    MOVLW	255
    XORWF	TIMER_MINUTOS1, W
    BTFSC	STATUS, 2
    CALL	AUHORAS_1
    RETURN 
    
AUHORAS_1:	
    CLRF    TIMER_MINUTOS1		; Limpiamos la variable cent
    MOVLW   9			; Movemos el valor literal 100 a W
    SUBWF   TIMER_MINUTOS1, W		; A cien le restamos cantidad y lo guardamos en F
    BTFSC   STATUS, 2		; Chequemoa la bandera STATUS
    GOTO    $+3			; Nos adelantamos tres posiciones
    INCF    TIMER_MINUTOS1		; Incrementamos cent
    GOTO    $-5			; Regresamos cinco posiciones
    
    DECF    TIMER_MINUTOS2
    CALL    ATODO_CERO_H
    RETURN
    
ATODO_CERO_H:
    MOVLW	0
    XORWF	TIMER_MINUTOS2, W
    BTFSS	STATUS, 2
    RETURN
	
    MOVLW	1
    XORWF	TIMER_MINUTOS1, W
    BTFSC	STATUS, 2
    DECF	Achequeo_underflow2
    RETURN
    
ASEGUIR:
    BTFSC   PORTB, BEDITAR
    BCF	    DECREMENTAR, 0
    BSF	    TMR1ON
    RETURN
    

;--------------------------------------------


CONFIG_TMR1:
    BANKSEL T1CON	    ; Cambiamos a banco 00
    BCF	    TMR1CS	    ; Reloj interno
    BCF	    T1OSCEN	    ; Apagamos LP
    BSF	    T1CKPS1	    ; Prescaler 1:8
    BSF	    T1CKPS0
    BCF	    TMR1GE	    ; TMR1 siempre contando
    BSF	    TMR1ON	    ; Encendemos TMR1
    
    RESET_TMR1 0xF3, 0xCB   ; TMR1 a 1s
    RETURN
    
;------- VALORES Y DISPLAYS HEXADECIMALES/BINARIOS---------- 
   
MOSTRAR_VALOR:
    BCF	    PORTD, 0		; Apagamos display de nibble alto
    BCF	    PORTD, 1		; Apagamos display de nibble bajo
    BCF	    PORTD, 2		; Apagamos display de nibble centenas
    BCF	    PORTD, 3		; Apagamos display de nibble decenas
    
    BTFSC   banderas, 0		; Verificamos bandera 0
    GOTO    DISPLAY_0		
    BTFSC   banderas, 1		; Verificamos bandera 1
    GOTO    DISPLAY_1
    BTFSC   banderas, 2		; Verificamos bandera 2
    GOTO    DISPLAY_2
    BTFSC   banderas, 3		; Verificamos bandera 3
    GOTO    DISPLAY_3

    
DISPLAY_0:			
    MOVF    HORAS1, W	; Movemos display a W
    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
    BSF	    PORTD, 1	; Encendemos display de nibble bajo
    BCF	    banderas, 0	; Apagamos la bandera actual
    BSF	    banderas, 1	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

DISPLAY_1:
    MOVF    HORAS2, W	; Movemos display+1 a W
    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
    BSF	    PORTD, 0	; Encendemos display de nibble alto
    BCF	    banderas, 1	; Apagamos la bandera actua
    BSF	    banderas, 2	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN
    
    ; Los tres display que mostraran el valor de hexadecimal a decimal
    
DISPLAY_2:
    MOVF    MINUTOS2, W	; Movemos centenas a W
    MOVWF   PORTC		; Movemos valor de tabla a PORTC
    BSF	    PORTD, 2	; Prendemos el display de las centenas
    BCF	    banderas, 2	; Apagamos la bandera actua
    BSF	    banderas, 3	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN
	
DISPLAY_3:
    MOVF    MINUTOS1, W	; Movemos decenas a W
    MOVWF   PORTC		; Movemos valor de tabla a PORTC
    BSF	    PORTD, 3	; Prendemos el display de las decenas
    CLRF    banderas
    RETURN
	
OBTENER_NIBBLE:			;    Ejemplo:
				; Obtenemos nibble bajo
    MOVLW   0x0F		;    Valor = 1101 0101
    ANDWF   valor, W		;	 AND 0000 1111
    MOVWF   nibbles		;	     0000 0101	
				; Obtenemos nibble alto
    MOVLW   0xF0		;     Valor = 1101 0101
    ANDWF   valor, W		;	  AND 1111 0000
    MOVWF   nibbles+1		;	      1101 0000
    SWAPF   nibbles+1, F	;	      0000 1101	
    RETURN
    
    
    
;---------CONTADORES DECIMALES------------
   
SET_DISPLAY:
    BTFSS   BANDERA_T, 0
    CALL    MOSTRAR_RELOJ
    BTFSC   BANDERA_T, 1
    CALL    MOSTRAR_TIMER
    BTFSC   BANDERA_T, 2
    CALL    MOSTRAR_FECHA
    RETURN

MOSTRAR_RELOJ:
    TABLA_DISPLAYS HOR2, HOR1, MIN2, MIN
    RETURN
    
MOSTRAR_TIMER:
    TABLA_DISPLAYS TIMER_MINUTOS2, TIMER_MINUTOS1, TIMER_SEGUNDOS2, TIMER_SEGUNDOS1
    RETURN 
    
MOSTRAR_FECHA:
    TABLA_DISPLAYS MES2, MES1, DIAS2, DIAS1
    RETURN
    
    
ORG 400h
    
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 2		; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
 /* RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F */

 END




