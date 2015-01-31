

		INCLUDE	tm4c123gh6pm.s
		
;светодиоды, которые нужно контролировать
RED       	EQU 0x02 ;0x10 в регистре флагов
BLUE      	EQU 0x04 ;0x20 в регистре флагов
GREEN     	EQU 0x08 ;0x30 в регистре флагов

;достоверное количество состояний 0 и 1, который нужно считать для антидребегза
NUMBER_STATE_CONTROL EQU 0x03

DEBOUNCE_TIME	EQU 0x1046A ;время между считываением состояния и реакцией на него 66666 циклов/100 мкс
WAITED_STATE_1	EQU 0x10 ;
WAITED_STATE_0	EQU 0x00 ;
BUTTON_STATE_COUNTER	RN	R2	;регистр флагов
;IN BUTTON_STATE_COUNTER 0x0000.000X: IN SUBROUTINES STATE1, STATE0 X-COUNTER OF READING STEADY VALUES (0 OR 1).CAN BE 0,1,2,3
;IN BUTTON_STATE_COUNTER 0x0000.00X0: IN SUBROUTINES READ_BUTTON_AND_WAIT_0, READ_BUTTON_AND_WAIT_1 
;X - COUNTER OF NUMBER . CAN BE 0,1
			
		AREA    |.text|, CODE, READONLY, ALIGN=2
		ENTRY
        THUMB
        EXPORT  START
;=================MACRO===================================
				MACRO
$label1			REGSETUP $REGADDR, $BITCLR, $BITSET

$label1			LDR R1, =$REGADDR
				LDR R0,[R1]
				BIC	R0,#$BITCLR
				ORR R0,#$BITSET
				STR R0,[R1]
				MEND

;=========================================================
;================SUBROUTINES==============================
TIM0_START	; reg GPTM0CTL-> bit 0 TAEN=1->TIMER0 START	
			LDR R1, =TIMER0_CTL_R
			MOV R0,	#0x00000001
			STR R0, 	[R1]
			BX 	LR
;=========================================================			
TIM0_STOP	; reg GPTM0ICR-> bit 0 TATOCINT=1-> WRITING 1 IN BIT TATOCINT CLEARS TATORIS BIT IN THE GPTMRIS REG	
			LDR R1, =TIMER0_ICR_R    
            LDR R0,     [R1]
            ORR R0, #0X00000001
            STR R0,[R1]
			BX 	LR
;=========================================================			
TICK_TOCK	; ожидание пока таймер не закочит отсчет
			LDR R1, =TIMER0_RIS_R 
            LDR R0,     [R1]
            CMP R0, #0X00000001
            BNE TICK_TOCK	
			BX 	LR
;=========================================================			
CHANGE_LED	;смена светодиода - реакция на нажатие
			MOV R0, R2 ; копируем регистр флагов в аккумулятор
			BIC R0,#0XF00 ; очищаем 3 тетраду
			CMP R0,#0x30  ; дошли до конца последовательности переключений?
			BNE QUIT 	;если нет - переключить на следующее состояние из последовательности
			
			;это выполняется, если текущий элемент последовательности - последний
			MOV R0, #GREEN ; заново записываем последовательность в стек
							;последовательность может быть длиннее			
			PUSH {R0}
			
			MOV R0, #BLUE
			PUSH {R0}
			
			MOV R0, #RED
			PUSH {R0}
			
			BIC R2,#0xF0 ; зануляем вторую тетраду регистра флагов
			
QUIT		
			ADD R2,#0x10; увеличиваем на 1 флаг текущего состояния последовательности
			POP {R0}; новый элемент последовательности переносим из стека в R0 
			LDR R1, =GPIO_PORTF_AHB_DATA_R ;адрес порта со светодиодами 
			STR R0, [R1];показываем новый светодиод
			BX	LR
;=========================================================			
READ_BUTTON_AND_WAIT; считывание и ожидание состояния кнопки

			MOV R0,	R2; копируем регистр флагов в аккумулятор
			BIC R0,R0,#0xFF; очищаем 1 и 2 тетраду
			CMP R0,#0X100; сравнение для проверки, какое состояние нужно получить при считывании - кнопка нажата или отпущена
			
			LDR R1, =GPIO_PORTF_AHB_DATA_R; считывание с кнопки
			LDR R0, [R1]
			
			BEQ IF_STATE_1; если кнопка не нажата переходим на  IF_STATE_1
			BNE	IF_STATE_0;если кнопка не нажата переходим на  IF_STATE_0
			
			
IF_STATE_1  AND R0,R0,#0x10           ; зануляем все значения, кроме значения считанного с кнопки
			CMP R0 ,#WAITED_STATE_1		;если это значение единица(кнопка не нажата)
			
			B	READ_QUIT				;
			
IF_STATE_0  AND R0,R0,#0x10           
			CMP R0 ,#WAITED_STATE_0		;если это значение нуль(кнопка нажата)
			
			B	READ_QUIT
			
READ_QUIT	BNE READ_BUTTON_AND_WAIT	;ждем значение дальше, если не равно
			
			BX 	LR						; иначе выход из подпрограммы
;=========================================================			
STATE_SET	; обработка нажатия
			ADD BUTTON_STATE_COUNTER, #0x1; добавить 1 к счетчику зафиксированных событий на кнопке 
			MOV R0, BUTTON_STATE_COUNTER  ; 
			BIC	R0,#0xFF0					
			CMP R0, #NUMBER_STATE_CONTROL ; проверка, сколько раз уже состояние кнопки было определено
			
			BNE READ_STATE; если меньше заданного числа - продолжаем определять состояние кнопки
			
			BIC BUTTON_STATE_COUNTER,#0x0F
			MOV R0,R2
			BIC R0, #0X0FF
			CMP R0, #0X100
			BICEQ BUTTON_STATE_COUNTER, #0XF00
			BEQ READ_STATE
			ORRNE BUTTON_STATE_COUNTER, #0X100
			BX LR
			
;==============SUBROUTINES END===========================

;==============MAIN==================================
START

					BL  INIT  

LED_ON	
			
						
					BL	CHANGE_LED
		
		
READ_STATE
					BL	READ_BUTTON_AND_WAIT
			
WAIT		
					BL	TIM0_START
			
					BL TICK_TOCK
			
					BL TIM0_STOP
		
TREAT_STATE		
					BL	STATE_SET
					B 	LED_ON
			
			
;==============MAIN END====================================

;============INIT======================================
INIT

; System clock properties FOR 40 MHz		


; reg RCC2-> bit 30 DIV400=1->SYSDIV2LSB & SYSDIV2 CREATE A 7 BIT DIVISOR USING THE 400 MHz PLL OTPUT		
DIV400		REGSETUP SYSCTL_RCC2_R,0,SYSCTL_RCC2_DIV400	

SET_BYPASS;	reg RCC->bit 11 BYPASS=1-> SYSTEM CLOCK IS DERIVED FROM THE OSC SOURSE			
			LDR R1, =SYSCTL_RCC_R
			LDR R0,	[R1]
			ORR R0, #SYSCTL_RCC_BYPASS
			STR R0, [R1]
			;reg RCC2->bit 11 BYPASS2=1-> SYSTEM CLOCK IS DERIVED FROM THE OSC SOURSE	
			LDR R1, =SYSCTL_RCC2_R
			LDR R0,	[R1]
			ORR R0, #SYSCTL_RCC2_BYPASS2
			STR R0, [R1]
			
CLR_USESYS	;reg RCC->bit 22 USESYSDIV=0-> SYSTEM CLOCK IS USED INDIVIDED
			LDR R1, =SYSCTL_RCC_R
			LDR R0,	[R1]
			BIC R0, #SYSCTL_RCC_USESYSDIV 
			STR R0, [R1]
			
XTAL_16MHZ	;reg RCC->bit 10-6 XTAL=0XD-> XTAL =16 MHZ
			LDR R1, =SYSCTL_RCC_R
			LDR R0,	[R1]
			BIC R0, #0X7C0
			ORR R0, #0X540 
			STR R0, [R1]
			
MOSC		;reg RCC2->bit 6-4 OSCSRC2=0-> SELECT INPUT SOURCE FOR THE OSC = MOCS
			LDR R1, =SYSCTL_RCC2_R
			LDR R0,	[R1]
			BIC R0, #0X30
			STR R0, [R1]
			
SYSDIV2		;reg RCC2->bit 28-23 SYSDIV2=0x02-> SELECT INPUT SYSTEM CLOCK DIVISOR = 10	
			LDR R1, =SYSCTL_RCC2_R
			LDR R0,	[R1]
			BIC R0, #0X0FF00000
			ORR R0, #0X02000000
			STR R0, [R1]
			
PLL_ON		;reg RCC2->bit 13 PWRDN2=0-> THE PLL IS ON
			LDR R1, =SYSCTL_RCC2_R
			LDR R0,	[R1]
			BIC R0, #0X00002000
			STR R0, [R1]
			
SET_USESYS	;reg RCC->bit 22 USESYSDIV=1-> SYSTEM CLOCK IS USED DIVIDED
			LDR R1, =SYSCTL_RCC_R
			LDR R0,	[R1]
			ORR R0, #SYSCTL_RCC_USESYSDIV 
			STR R0, [R1]
		
CLR_BYPASS2	;reg RCC2->bit 11 BYPASS2=0-> SYSTEM CLOCK IS USED DIVIDED BY THE DIVISOR SPECIFIED BY SYSDIV2
			LDR R1, =SYSCTL_RCC2_R
			LDR R0,	[R1]
			BIC R0, #SYSCTL_RCC2_BYPASS2
			STR R0, [R1]
		
USE_RCC2	;reg RCC2->bit 31 USERCC2=1-> THE RCC2 REGISTER FIELDS OVERRIDE THE RCC REGISTER FIELDS
			LDR R1, =SYSCTL_RCC2_R
			LDR R0,	[R1]
			ORR	R0,	#0XC0000000
			STR R0, [R1]

PLL_LOCK_WAIT	;WAIT FOR PLL LOCK							
			LDR R1, =SYSCTL_PLLSTAT_R
			
READ_PLLSTAT
			LDR R0,	[R1]
			CMP R0, #0X00000001
			BNE READ_PLLSTAT
			
;SPI0	properties - 4 MHZ SPH=0 SPO=0
SSI0_EN		
			MOV R0, #0x1
			LDR R1, =SYSCTL_RCGCSSI_R
			STR R0, [R1]	
SSI0_GPIO_A_ON ;reg RCGCGPIO->bit 1 R5=1-> ENABLE AND PROVIDE A CLOCK TO GPIO PORT A IN RUN MODE	
			MOV R0, #0x1	
			LDR R1, =SYSCTL_RCGCGPIO_R 
			STR R0, [R1]
SSI0_GPIO_PINS_ALTERN_FUNC
			MOV R0, #0x24
			LDR R1, =GPIO_PORTA_AFSEL_R
			STR R0, [R1] 
SSI0_GPIO_PINS_PCTL
			MOV32 R0, #0x200200
			LDR R1, =GPIO_PORTA_PCTL_R
			STR R0, [R1] 
SSI0_GPIO_PINS_DEN
			MOV R0, #0x24
			LDR R1, =GPIO_PORTA_DEN_R
			STR R0, [R1] 			
SSI0_CR1_SSE_CLEAR
			LDR R1, =SSI0_CR1_R
			LDR R0, [R1] 
			BIC R0, #SSI_CR1_SSE
			STR R0, [R1]
SSI0_CR1_SET_MASTER
			MOV R0, #0x0
			LDR R1, =SSI0_CR1_R
			STR R0, [R1]
SSI0_CLOCK_SOURCE
			MOV R0, #0x0
			LDR R1, =SSI0_CC_R 
			STR R0, [R1]
SSI0_CLOCK_PRESCALE_DIVISOR
			MOV R0, #0x2
			LDR R1, =SSI0_CPSR_R
			STR R0, [R1]
SSI0_CR0_SET_SCR
			LDR R1, =SSI0_CR0_R
			LDR R0, [R1]
			BIC R0, #SSI_CR0_SCR_M 
			ORR R0, #0x400
			STR R0, [R1]
SSI0_CR0_SET_SPH_SPO
			LDR R1, =SSI0_CR0_R
			LDR R0, [R1]
			BIC R0, #0xC0
;			ORR R0, #0x0
			STR R0, [R1]
SSI0_CR0_SET_FRF
			LDR R1, =SSI0_CR0_R
			LDR R0, [R1]
			BIC R0, #0x30
;			ORR R0, #0x0
			STR R0, [R1]
SSI0_CR0_DSS
			LDR R1, =SSI0_CR0_R
			LDR R0, [R1]
			BIC R0, #0xF
			ORR R0, #0x7
			STR R0, [R1]
SSI0_CR1_SSE_SET
			LDR R1, =SSI0_CR1_R
			LDR R0, [R1]
			ORR R0, #SSI_CR1_SSE
			STR R0, [R1]			
; GPIO properties - PF1,PF2,PF3 IS OUT FOR LIGHT LEDS	

GPIO_F_ON 	;reg RCGCGPIO->bit 5 R5=1-> ENABLE AND PROVIDE A CLOCK TO GPIO PORT F IN RUN MODE		
			MOV R0, #0x20	
			LDR R1, =SYSCTL_RCGCGPIO_R 
			STR R0, [R1]
			
			NOP
			NOP
			NOP   
			
GPIO_AHB_EN	;reg GPIOHBCTL->bit 5 R5=1-> ENABLE AHB BUS FOR GPIO PORT F AND PORT A	
			MOV R0, #0x21	
			LDR R1, =SYSCTL_GPIOHBCTL_R 
			STR R0, [R1]

GPIO_F_DIR	;reg GPIODIR->bit 3-1 GPIODIR=0B0000.1110 -> SETUP PINS PF1,PF2,PF3 AS OUTPUTS
			MOV R0, #0x0E	
			LDR R1, =GPIO_PORTF_AHB_DIR_R
			STR R0, [R1]

GPIO_F_DEN	;reg GPIODEN->bit 3-1 GPIODEN=0B0000.1110 -> SETUP PINS PF1,PF2,PF3 AS DIGITAL
			MOV R0, #0x1E	
			LDR R1, =GPIO_PORTF_AHB_DEN_R 
			STR R0, [R1]
GPIO_F_PUR	;reg GPIOPUR->bit 3-1 GPIODEN=0B0001.0000 -> SETUP PINS PF1,PF2,PF3 AS DIGITAL
			MOV R0, #0x10	
			LDR R1, =GPIO_PORTF_AHB_PUR_R 
			STR R0, [R1]

			
;TIMER0	properties - one-shot mode

TIM0_EN		;reg RCGCTIMER->bit1  RCGCTIMER=0X1-> GENERAL PURPOSE TIMER0 ENABLED
			LDR R1, =SYSCTL_RCGCTIMER_R 
			MOV R0, #0X1
			STR R0,[R1]

TIM0_0		
			LDR R1, =TIMER0_CFG_R
			MOV R0,	#0x0

TIM0_MODE	;reg GPTMTAMR>bit 0-1  TAMR=0X2-> PERIODIC TIMER MODE
			LDR R1, =TIMER0_TAMR_R
			MOV R0,	#0x1
			STR R0, [R1]

COUNT_VALUE;reg TAILR - PRELOAD COUNT VALUE
			LDR R1, =TIMER0_TAILR_R
			LDR R0, =DEBOUNCE_TIME
			STR R0, [R1]
			
			MOV R0, #GREEN
			PUSH {R0}
			
			MOV R0, #BLUE
			PUSH {R0}
			
			MOV R0, #RED
			PUSH {R0}
			
			MOV R2,#0x100
			
			
			BX LR
;===========INIT END==========================================

	ALIGN
	END