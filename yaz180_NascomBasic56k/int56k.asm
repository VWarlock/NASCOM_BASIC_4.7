;==================================================================================
; Contents of this file are copyright Phillip Stevens
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; Initialisation routines to suit Z8S180 CPU, with internal USART.
;
; Internal USART interrupt driven serial I/O to run modified NASCOM Basic 4.7.

; Full input and output buffering with incoming data hardware handshaking.
; Handshake shows full before the buffer is totally filled to
; allow run-on from the sender.
;
; https://github.com/feilipu/
;
; https://feilipu.me/
;
;==================================================================================
;
; Z180 Register Mnemonics
;

CNTLA0          .EQU    $00     ; ASCI Control Reg A Ch 0
CNTLA1          .EQU    $01     ; ASCI Control Reg A Ch 1
CNTLB0          .EQU    $02     ; ASCI Control Reg B Ch 0
CNTLB1          .EQU    $03     ; ASCI Control Reg B Ch 1
STAT0           .EQU    $04     ; ASCI Status  Reg   Ch 0
STAT1           .EQU    $05     ; ASCI Status  Reg   Ch 1
TDR0            .EQU    $06     ; ASCI Tx Data Reg   Ch 0
TDR1            .EQU    $07     ; ASCI Tx Data Reg   Ch 1
RDR0            .EQU    $08     ; ASCI Rx Data Reg   Ch 0
RDR1            .EQU    $09     ; ASCI Rx Data Reg   Ch 1

ASEXT0          .EQU    $12     ; ASCI Extension Control Reg Ch 0 (Z8S180 & higher Only)
ASEXT1          .EQU    $13     ; ASCI Extension Control Reg Ch 1 (Z8S180 & higher Only)

ASTC0L          .EQU    $1A     ; ASCI Time Constant Ch 0 Low (Z8S180 & higher Only)
ASTC0H          .EQU    $1B     ; ASCI Time Constant Ch 0 High (Z8S180 & higher Only)
ASTC1L          .EQU    $1C     ; ASCI Time Constant Ch 1 Low (Z8S180 & higher Only)
ASTC1H          .EQU    $1D     ; ASCI Time Constant Ch 1 High (Z8S180 & higher Only)

CNTR            .EQU    $0A     ; CSI/O Control Reg
TRDR            .EQU    $0B     ; CSI/O Tx/Rx Data Reg

TMDR0L          .EQU    $0C     ; Timer Data Reg Ch 0 Low
TMDR0H          .EQU    $0D     ; Timer Data Reg Ch 0 High
RLDR0L          .EQU    $0E     ; Timer Reload Reg Ch 0 Low
RLDR0H          .EQU    $0F     ; Timer Reload Reg Ch 0 High
TCR             .EQU    $10     ; Timer Control Reg

TMDR1L          .EQU    $14     ; Timer Data Reg Ch 1 Low
TMDR1H          .EQU    $15     ; Timer Data Reg Ch 1 High
RLDR1L          .EQU    $16     ; Timer Reload Reg Ch 1 Low
RLDR1H          .EQU    $17     ; Timer Reload Reg Ch 1 High

FRC             .EQU    $18     ; Free-Running Counter

CMR             .EQU    $1E     ; CPU Clock Multiplier Reg (Z8S180 & higher Only)
CCR             .EQU    $1F     ; CPU Control Reg (Z8S180 & higher Only)

SAR0L           .EQU    $20     ; DMA Source Addr Reg Ch0-Low
SAR0H           .EQU    $21     ; DMA Source Addr Reg Ch0-High
SAR0B           .EQU    $22     ; DMA Source Addr Reg Ch0-Bank
DAR0L           .EQU    $23     ; DMA Dest Addr Reg Ch0-Low
DAR0H           .EQU    $24     ; DMA Dest Addr Reg Ch0-High
DAR0B           .EQU    $25     ; DMA Dest ADDR REG CH0-Bank
BCR0L           .EQU    $26     ; DMA Byte Count Reg Ch0-Low
BCR0H           .EQU    $27     ; DMA Byte Count Reg Ch0-High
MAR1L           .EQU    $28     ; DMA Memory Addr Reg Ch1-Low
MAR1H           .EQU    $29     ; DMA Memory Addr Reg Ch1-High
MAR1B           .EQU    $2A     ; DMA Memory Addr Reg Ch1-Bank
IAR1L           .EQU    $2B     ; DMA I/O Addr Reg Ch1-Low
IAR1H           .EQU    $2C     ; DMA I/O Addr Reg Ch2-High
BCR1L           .EQU    $2E     ; DMA Byte Count Reg Ch1-Low
BCR1H           .EQU    $2F     ; DMA Byte Count Reg Ch1-High
DSTAT           .EQU    $30     ; DMA Status Reg
DMODE           .EQU    $31     ; DMA Mode Reg
DCNTL           .EQU    $32     ; DMA/Wait Control Reg

IL              .EQU    $33     ; INT Vector Low Reg
ITC             .EQU    $34     ; INT/TRAP Control Reg

RCR             .EQU    $36     ; Refresh Control Reg

CBR             .EQU    $38     ; MMU Common Base Reg
BBR             .EQU    $39     ; MMU Bank Base Reg
CBAR            .EQU    $3A     ; MMU Common/Bank Area Reg

OMCR            .EQU    $3E     ; Operation Mode Control Reg
ICR             .EQU    $3F     ; I/O Control Reg

;==================================================================================
;
; Some bit definitions used with the Z-180 on-chip peripherals:
;

; ASCI Control Reg A

SER_MPE         .EQU   $80    ; Multi Processor Enable
SER_RE          .EQU   $40    ; Receive Enable
SER_TE          .EQU   $20    ; Transmit Enable
SER_RTS0        .EQU   $10    ; _RTS Request To Send
SER_EFR         .EQU   $08    ; Error Flag Reset

SER_7N1         .EQU   $00    ; 7 Bits No Parity 1 Stop Bit
SER_7N2         .EQU   $01    ; 7 Bits No Parity 2 Stop Bits
SER_7P1         .EQU   $02    ; 7 Bits    Parity 1 Stop Bit
SER_7P2         .EQU   $03    ; 7 Bits    Parity 2 Stop Bits
SER_8N1         .EQU   $04    ; 8 Bits No Parity 1 Stop Bit
SER_8N2         .EQU   $05    ; 8 Bits No Parity 2 Stop Bits
SER_8P1         .EQU   $06    ; 8 Bits    Parity 1 Stop Bit
SER_8P2         .EQU   $07    ; 8 Bits    Parity 2 Stop Bits

; ASCI Control Reg B

SER_MPBT        .EQU   $80    ; Multi Processor Bit Transmit
SER_MP          .EQU   $40    ; Multi Processor
SER_PS          .EQU   $20    ; Prescale PHI by 10 (PS 0) or 30 (PS 1)
SER_PEO         .EQU   $10    ; Parity Even or Odd
SER_DR          .EQU   $08    ; Divide SS by 16 (DR 0) or 64 (DR 1)

                              ; Baud Rate Selection
SER_SS_DIV_1    .EQU   $00    ; Divide PS by  1
SER_SS_DIV_2    .EQU   $01    ; Divide PS by  2
SER_SS_DIV_4    .EQU   $02    ; Divide PS by  4
SER_SS_DIV_8    .EQU   $03    ; Divide PS by  8
SER_SS_DIV_16   .EQU   $04    ; Divide PS by 16
SER_SS_DIV_32   .EQU   $05    ; Divide PS by 32
SER_SS_DIV_64   .EQU   $06    ; Divide PS by 64
SER_SS_EXT      .EQU   $07    ; External Clock Source <= PHI / 40

                              ; BAUD Rate = PHI / PS / SS / DR

; ASCI Status Reg

SER_RDRF        .EQU   $80    ; Receive Data Register Full
SER_OVRN        .EQU   $40    ; Overrun (Received Byte)
SER_PE          .EQU   $20    ; Parity Error (Received Byte)
SER_FE          .EQU   $10    ; Framing Error (Received Byte)
SER_RIE         .EQU   $08    ; Receive Interrupt Enabled
SER_DCD0        .EQU   $04    ; _DCD0 Data Carrier Detect USART0
SER_CTS1        .EQU   $04    ; _CTS1 Clear To Send USART1
SER_TDRE        .EQU   $02    ; Transmit Data Register Empty
SER_TIE         .EQU   $01    ; Transmit Interrupt Enabled

; CPU Clock Multiplier Reg (CMR) (Z8S180 & higher Only)

CMR_X2          .EQU   $80    ; CPU x2 XTAL Multiplier Mode
CMR_LN_XTAL     .EQU   $40    ; Low Noise Crystal 

; CPU Control Reg (CCR) (Z8S180 & higher Only)

CCR_XTAL_X2     .EQU   $80    ; PHI = XTAL Mode
CCR_STANDBY     .EQU   $40    ; STANDBY after SLEEP
CCR_BREXT       .EQU   $20    ; Exit STANDBY on BUSREQ
CCR_LNPHI       .EQU   $10    ; Low Noise PHI (30% Drive)
CCR_IDLE        .EQU   $08    ; IDLE after SLEEP
CCR_LNIO        .EQU   $04    ; Low Noise I/O Signals (30% Drive)
CCR_LNCPUCTL    .EQU   $02    ; Low Noise CPU Control Signals (30% Drive)
CCR_LNAD        .EQU   $01    ; Low Noise Address and Data Signals (30% Drive)

; Refresh Control Reg (RCR)

RCR_REFE        .EQU   $80    ; DRAM Refresh Enable (0 Disabled)
RCR_REFW        .EQU   $40    ; DRAM Refresh 2 or 3 Wait states (0 2 Wait States)

; Interrupt vectors (offsets) for Z180/HD64180 internal interrupts

INT1_VECTOR     .EQU   $00    ; external /INT1 
INT2_VECTOR     .EQU   $02    ; external /INT2 
PRT0_VECTOR     .EQU   $04    ; PRT channel 0 
PRT1_VECTOR     .EQU   $06    ; PRT channel 1 
DMA0_VECTOR     .EQU   $08    ; DMA channel 0 
DMA1_VECTOR     .EQU   $0A    ; DMA Channel 1 
CSIO_VECTOR     .EQU   $0C    ; Clocked serial I/O 
ASCI0_VECTOR    .EQU   $0E    ; Async channel 0 
ASCI1_VECTOR    .EQU   $10    ; Async channel 1 
INCAP_VECTOR    .EQU   $12    ; input capture 
OUTCMP_VECTOR   .EQU   $14    ; output compare 
TIMOV_VECTOR    .EQU   $16    ; timer overflow 

;==================================================================================
;
; DEFINES SECTION

                               ; end of ASCI stuff is $210D
                               ; set BASIC Work space WRKSPC $2120

TEMPSTACK       .EQU     $21CB ; Top of BASIC line input buffer (CURPOS WRKSPC+0ABH)
                               ; so it is "free ram" when BASIC resets

CR              .EQU     0DH
LF              .EQU     0AH
CS              .EQU     0CH   ; Clear screen

;==================================================================================
;
; VARIABLES SECTION

SER_RX_BUFSIZE  .EQU     $F0  ; Size of the Rx Buffer, 239 Bytes
SER_TX_BUFSIZE  .EQU     $10  ; Size of the Tx Buffer, 15 Bytes
     
serRxBuf        .EQU     $2000
serRxInPtr      .EQU     serRxBuf+SER_RX_BUFSIZE+1
serRxOutPtr     .EQU     serRxInPtr+2
serRxBufUsed    .EQU     serRxOutPtr+2
serTxBuf        .EQU     serRxBufUsed+1
serTxInPtr      .EQU     serTxBuf+SER_TX_BUFSIZE+1
serTxOutPtr     .EQU     serTxInPtr+2
serTxBufUsed    .EQU     serTxOutPtr+2
basicStarted    .EQU     serTxBufUsed+1

;==================================================================================
;
; CODE SECTION 

                .ORG $0000
;------------------------------------------------------------------------------
; Reset

RST00:          DI             ;Disable interrupts
                JP       INIT  ;Initialize Hardware and go

;------------------------------------------------------------------------------
; TX a character over RS232 

                .ORG     0008H
RST08:           JP      TXA

;------------------------------------------------------------------------------
; RX a character over RS232 Channel A [Console], hold here until char ready.

                .ORG 0010H
RST10:           JP      RXA

;------------------------------------------------------------------------------
; Check serial status

                .ORG 0018H
RST18:           JP      CKINCHAR

;------------------------------------------------------------------------------
; INTERRUPT VECTOR ASCI Channel 0 [ IL = $01 for Vectors at $20 - $36 ]

                .ORG     002EH
                JP       serialInt

;------------------------------------------------------------------------------
; RST 38 - INTERRUPT VECTOR INT0 [ with IM 1 ] - UNUSED

                .ORG     0038H
RST38:          DI             ;Disable interrupts
                JP       INIT  ;Initialize Hardware and go
                
;------------------------------------------------------------------------------
; ASCI Code

                .ORG     0040H                              
serialInt:

        push af
        push hl

; start doing the Rx stuff

        in0 a, (STAT0)              ; get the status of the ASCI
        and SER_RDRF                ; check whether a byte has been received
        jr z, tx_check              ; if not, go check for bytes to transmit 

        in0 a, (RDR0)               ; Get the received byte from the ASCI 
        ld l, a                     ; Move Rx byte to l

        ld a, (serRxBufUsed)        ; Get the number of bytes in the Rx buffer
        cp SER_RX_BUFSIZE           ; check whether there is space in the buffer
        jr nc, tx_check             ; buffer full, check if we can send something

        ld a, l                     ; get Rx byte from l
        ld hl, (serRxInPtr)         ; get the pointer to where we poke
        ld (hl), a                  ; write the Rx byte to the serRxInPtr address

        inc hl                      ; move the Rx pointer along
        ld a, l	                    ; move low byte of the Rx pointer
        cp (serRxBuf + SER_RX_BUFSIZE) & $FF
        jr nz, no_rx_wrap
        ld hl, serRxBuf             ; we wrapped, so go back to start of buffer
    	
no_rx_wrap:

        ld (serRxInPtr), hl         ; write where the next byte should be poked

        ld hl, serRxBufUsed
        inc (hl)                    ; atomically increment Rx buffer count

; now start doing the Tx stuff

tx_check:

        ld a, (serTxBufUsed)        ; get the number of bytes in the Tx buffer
        or a                        ; check whether it is zero
        jr z, tie_clear             ; if the count is zero, then disable the Tx Interrupt

        in0 a, (STAT0)              ; get the status of the ASCI
        and SER_TDRE                ; check whether a byte can be transmitted
        jr z, tx_end                ; if not, then end

        ld hl, (serTxOutPtr)        ; get the pointer to place where we pop the Tx byte
        ld a, (hl)                  ; get the Tx byte
        out0 (TDR0), a              ; output the Tx byte to the ASCI

        inc hl                      ; move the Tx pointer along
        ld a, l                     ; get the low byte of the Tx pointer
        cp (serTxBuf + SER_TX_BUFSIZE) & $FF
        jr nz, no_tx_wrap
        ld hl, serTxBuf             ; we wrapped, so go back to start of buffer

no_tx_wrap:

        ld (serTxOutPtr), hl        ; write where the next byte should be popped

        ld hl, serTxBufUsed
        dec (hl)                    ; atomically decrement current Tx count
        jr nz, tx_end               ; if we've more Tx bytes to send, we're done for now
        
tie_clear:

        in0 a, (STAT0)              ; get the ASCI status register
        and ~SER_TIE                ; mask out (disable) the Tx Interrupt
        out0 (STAT0), a             ; set the ASCI status register

tx_end:

        pop hl
        pop af
        
        ei
        reti

;------------------------------------------------------------------------------
RXA:
waitForRxChar:

        ld a, (serRxBufUsed)        ; get the number of bytes in the Rx buffer

        or a                        ; see if there are zero bytes available
        jr z, waitForRxChar         ; wait, if there are no bytes available
        
        push hl                     ; Store HL so we don't clobber it

        ld hl, (serRxOutPtr)        ; get the pointer to place where we pop the Rx byte
        ld a, (hl)                  ; get the Rx byte
        push af                     ; save the Rx byte on stack

        inc hl                      ; move the Rx pointer along
        ld a, l                     ; get the low byte of the Rx pointer
        cp (serRxBuf + SER_RX_BUFSIZE) & $FF
        jr nz, get_no_rx_wrap
        ld hl, serRxBuf             ; we wrapped, so go back to start of buffer

get_no_rx_wrap:

        ld (serRxOutPtr), hl        ; write where the next byte should be popped

        ld hl,serRxBufUsed
        dec (hl)                    ; atomically decrement Rx count

        pop af                      ; get the Rx byte from stack
        pop hl                      ; recover HL

        ret                         ; char ready in A

;------------------------------------------------------------------------------
TXA:
        push hl                     ; Store HL so we don't clobber it        
        ld l, a                     ; Store Tx character 

        ld a, (serTxBufUsed)        ; Get the number of bytes in the Tx buffer
        cp SER_TX_BUFSIZE           ; check whether there is space in the buffer
        jr nc, clean_up_tx          ; buffer full, so abandon Tx
        
        ld a, l                     ; Retrieve Tx character
        ld hl, (serTxInPtr)         ; get the pointer to where we poke
        ld (hl), a                  ; write the Tx byte to the serTxInPtr   
        inc hl                      ; move the Tx pointer along

        ld a, l                     ; move low byte of the Tx pointer
        cp (serTxBuf + SER_TX_BUFSIZE) & $FF
        jr nz, put_no_tx_wrap
        ld hl, serTxBuf             ; we wrapped, so go back to start of buffer

put_no_tx_wrap:

        ld (serTxInPtr), hl         ; write where the next byte should be poked

        ld hl, serTxBufUsed
        inc (hl)                    ; atomic increment of Tx count

        di                          ; critical section begin
       
        in0 a, (STAT0)              ; get the ASCI status register
        or SER_TIE                  ; mask in (enable) the Tx Interrupt
        out0 (STAT0), a             ; set the ASCI status register
        
        ei                          ; critical section end
        
clean_up_tx:        
        
        pop hl                      ; recover HL

        ret

;------------------------------------------------------------------------------
CKINCHAR:      LD        A,(serRxBufUsed)
               CP        $0
               RET

PRINT:         LD        A,(HL)          ; Get character
               OR        A               ; Is it $00 ?
               RET       Z               ; Then RETurn on terminator
               RST       08H             ; Print it
               INC       HL              ; Next Character
               JR        PRINT           ; Continue until $00
               RET
;------------------------------------------------------------------------------
INIT:
               XOR       A               ; $00
                                         
                                         ; Disable external interrupts  
               OUT0      (ITC),A         ; until Int Vector Table initialized
               
                                         ; Disable PRT downcounting,
               OUT0      (TCR),A         ; until Int Vector Table initialized
                
                                         ; Clear Refresh Control Reg (RCR)
               OUT0      (RCR),A         ; DRAM Refresh Enable (0 Disabled)
                
                                         ; Bypass PHI = crystal / 2
                                         ; if using ZS8180 or Z80182 at High-Speed
               LD	     A,CCR_XTAL_X2   ; Set Hi-Speed flag: PHI = crystal
               OUT0      (CCR),A         ; CPU Control Reg (CCR)

               EX        (SP),IY         ; (settle)
               EX        (SP),IY         ; (settle)

                                         ; Set internal clock = crystal x 2
                                         ; if using ZS8180 or Z80182 at High-Speed
               LD        A,CMR_X2        ; Set Hi-Speed flag
               OUT0	     (CMR),A         ; CPU Clock Multiplier Reg (CMR)

                                         ; Set Logical Addresses
                                         ; $8000-$FFFF RAM CA1
                                         ; $4000-$7FFF RAM BANK
                                         ; $2000-$3FFF RAM CA0
                                         ; $0000-$1FFF Flash CA0
               LD        A,84H           ; Set New Common / Bank Areas
               OUT0      (CBAR),A        ; for RAM
               
                                         ; Physical Addresses
               LD        A,80H           ; Set New Common 1 Area $80000
               OUT0      (CBR),A
               
               LD        A,40H           ; Set New Bank Area $40000
               OUT0      (BBR),A
               
               LD        HL,TEMPSTACK    ; Temp stack
               LD        SP,HL           ; Set up a temporary stack
               
               LD        HL,serRxBuf     ; Initialise Rx Buffer
               LD        (serRxInPtr),HL
               LD        (serRxOutPtr),HL

               LD        HL,serTxBuf     ; Initialise Tx Buffer
               LD        (serTxInPtr),HL
               LD        (serTxOutPtr),HL              
               
               XOR       A               ; 0 the accumulator
               LD        (serRxBufUsed),A
               LD        (serTxBufUsed),A
               
                                         ; load the default ASCI configuration
                                         ; 
                                         ; BAUD = 115200 8n1
                                         ; receive enabled
                                         ; transmit enabled                                         
                                         ; receive interrupt enabled
                                         ; transmit interrupt disabled
                                         
               LD        A,SER_RE|SER_TE|SER_8N1
               OUT0      (CNTLA0),A      ; output to the ASCI0 control A reg
               
                                         ; PHI / PS / SS / DR = BAUD Rate
                                         ; PHI = 18.432MHz
                                         ; BAUD = 115200 = 18432000 / 10 / 1 / 16 
                                         ; PS 0, SS_DIV_1 0, DR 0           
               XOR        A              ; BAUD = 115200
               OUT0      (CNTLB0),A      ; output to the ASCI0 control B reg
               
               LD        A,SER_RIE       ; receive interrupt enabled
               OUT0      (STAT0),A       ; output to the ASCI0 status reg
               
                                         ; set interrupt vector for ASCI Channel 0
               LD        A,$20           ; IL = $20 [001] for Vectors at $20 - $2F
               OUT0      (IL),A          ; output to the Interrupt Vector Low reg
                                         
               IM        1               ; interrupt mode 1 for INT0 (unused)
               EI                        ; enable interrupts
               
               LD        HL,SIGNON1      ; Sign-on message
               CALL      PRINT           ; Output string
               LD        A,(basicStarted); Check the BASIC STARTED flag
               CP        'Y'             ; to see if this is power-up
               JR        NZ,COLDSTART    ; If not BASIC started then always do cold start
               LD        HL,SIGNON2      ; Cold/warm message
               CALL      PRINT           ; Output string
CORW:
               CALL      RXA
               AND       %11011111       ; lower to uppercase
               CP        'C'
               JR        NZ, CHECKWARM
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
COLDSTART:     LD        A,'Y'           ; Set the BASIC STARTED flag
               LD        (basicStarted),A
               JP        $01C0           ; <<<< Start BASIC COLD
CHECKWARM:
               CP        'W'
               JR        NZ, CORW
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
               JP        $01C3           ; <<<< Start BASIC WARM
              

SIGNON1:       .BYTE     "YAZ180 - feilipu",CR,LF,0
SIGNON2:       .BYTE     CR,LF
               .BYTE     "Cold or warm start (C|W) ?",0

               .END