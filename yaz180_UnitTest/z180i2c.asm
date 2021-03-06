;==============================================================================
; Contents of this file are copyright Phillip Stevens
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; https://github.com/feilipu/
;
; https://feilipu.me/
;
;
; This work was authored in Marrakech, Morocco during May/June 2017.

;==============================================================================
;
; INCLUDES SECTION
;

#include "d:/yaz180.h"

;==============================================================================
;
; DEFINES SECTION
;

;   from Nascom Basic Symbol Tables .ORIG $0390
DEINT       .EQU    $0C47   ;Function DEINT to get USR(x) into DE registers
ABPASS      .EQU    $13BD   ;Function ABPASS to put output into AB register

location    .equ    $3000   ;Where this driver will exist
program     .equ    $4000   ;Where this program will exist

;------------------------------------------------------------------
;
; PCA9665 - Fm+ parallel bus to I2C-bus controller
;
; The PCA9665/PCA9665A acts as an interface device between standard high-speed
; parallel buses and the serial I 2 C-bus. On the I 2 C-bus,
; it can act either as a master or slave.
;
; Bidirectional data transfer between the I 2 C-bus and the parallel-bus
; microcontroller is carried out on a byte or buffered basis,
; using either an interrupt or polled handshake.
;
; The PCA9665/PCA9665A contains eleven registers which are used to configure
; the operation of the device as well as to send and receive serial data.
; There are four registers that can be accessed directly and seven registers
; that are accessed indirectly by setting a register pointer.
;
; The four direct registers are selected by setting pins A0 and A1 to the
; appropriate logic levels before a read or write operation is executed on
; the parallel bus.
;
; The seven indirect registers require that the INDPTR (indirect register
; pointer, one of the four direct registers described above) is initially
; loaded with the address of the register in the indirect address space
; before a read or write is performed to the INDIRECT data field.
;
;   DIRECT REGISTERS
;   Register Name   Register function   A1  A0  Read/Write  Default
;   I2CSTA          status              0   0   R           F8h
;   INDPTR          indirect register   0   0   W           00h
;                   pointer
;   I2CDAT          data                0   1   R/W         00h
;   I2CCON          control             1   1   R/W         00h
;   INDIRECT        indirect data field 1   0   R/W         00h
;                   access
;
;   INDIRECT REGISTERS
;   Register name   Register function   INDPTR  Read/Write  Default
;   I2CCOUNT        byte count          00h     R/W         01h
;   I2CADR          own address         01h     R/W         E0h
;   I2CSCLL         SCL LOW period      02h     R/W         9Dh
;   I2CSCLH         SCL HIGH period     03h     R/W         86h
;   I2CTO           time-out            04h     R/W         FFh
;   I2CPRESET       parallel s/w reset  05h     W           00h [A5h 5Ah]
;   I2CMODE         I2C-bus mode        06h     R/W         00h
;
;   Bits in I2CSTA
;
;   Bit 7:2 = ST[5:0]   status code corresponding I2C states
;   Bit 1:0             always reads zero
;
;   Bits in INDPTR
;
;   Bit 7:3             reserved, must always be written to zero
;   Bit 2:0 = IP[2:0]   address of the indirect register
;
;   Bits in I2CCON
;
;   Bit 7   = AA        Assert Acknowledge Flag
;   Bit 6   = ENSIO     Bus Controller Enable change only when I2C bus idle.
;   Bit 5   = STA       Start Flag
;   Bit 4   = STO       Stop Flag
;   Bit 3   = SI        Serial Interrupt Flag
;   Bit 2:1             reserved, must always be written to zero
;   Bit 0   = MODE      Mode Flag, 1 = byte mode, 0 = buffered mode
;  
;   Remark: Since none of the registers should be written to via
;   the parallel interface once the Serial Interrupt line has been
;   de-asserted, all the other registers that need to be modified
;   should be written to before the content of the I2CCON register
;   is modified.
;
;   Bits in I2CCOUNT
;
;   Bit 7   = LB        Last Byte control bit
;   Bit 6   = BC[6:0]   Number of bytes to be read or written
;                       (up to 68 bytes)
;
;   Bits in I2CADR
;
;   Bit 7:1 = AD[7:1]   Own slave address
;   Bit 0   = GC        General Call
;
;   Bits in I2MODE
;
;   Bit 7:2             reserved, must always be written to zero
;   Bit 1:0 = AC[1:0]   Bus Mode 00b Std 01b Fast 10b Fast+ 11b Turbo
;
;------------------------------------------------------------------------------
; Hardware Configuration

; PCA9665 I2C Port Definitions

PCA1        .EQU    $A000   ; Base Address for PCA9665 1 I/O
PCA2        .EQU    $8000   ; Base Address for PCA9665 2 I/O

; PCA9665 device addressing

PCA1_ADDR   .EQU    $A0     ; distinguish the device address, with MSB
PCA2_ADDR   .EQU    $80     ; only 3 MSB bits are H/W decoded %111xxxxx

;------------------------------------------------------------------------------
; I2C I/O Register Addressing
;

; PCA9665 direct registers
PCA_STA     .EQU    $00     ; STATUS            Read Only
PCA_INDPTR  .EQU    $00     ; INDIRECT Pointer  Write Only
PCA_DAT     .EQU    $01     ; DATA              Read/Write
PCA_IND     .EQU    $02     ; INDIRECT          Read/Write
PCA_CON     .EQU    $03     ; CONTROL           Read/Write

; PCA9665 indirect registers
PCA_ICOUNT  .EQU    $00     ; Byte Count for buffered mode
PCA_IADR    .EQU    $01     ; OWN Address
PCA_ISCLL   .EQU    $02     ; SCL LOW period
PCA_ISCLH   .EQU    $03     ; SCL HIGH period
PCA_ITO     .EQU    $04     ; TIMEOUT
PCA_IPRESET .EQU    $05     ; Parallel bus reset
PCA_IMODE   .EQU    $06     ; I2C Bus mode

;------------------------------------------------------------------------------
; I2C PCA9665 Control Bits
;

;   Bits in PCA_STA

I2C_STA_ILLEGAL_START_STOP      .EQU    $00
I2C_STA_MASTER_START_TX         .EQU    $08
I2C_STA_MASTER_RESTART_TX       .EQU    $10
I2C_STA_MASTER_SLA_W_ACK        .EQU    $18
I2C_STA_MASTER_SLA_W_NAK        .EQU    $20
I2C_STA_MASTER_DATA_W_ACK       .EQU    $28
I2C_STA_MASTER_DATA_W_NAK       .EQU    $30
I2C_STA_MASTER_ARB_LOST         .EQU    $38
I2C_STA_MASTER_SLA_R_ACK        .EQU    $40
I2C_STA_MASTER_SLA_R_NAK        .EQU    $48
I2C_STA_MASTER_DATA_R_ACK       .EQU    $50
I2C_STA_MASTER_DATA_R_NAK       .EQU    $58
I2C_STA_SLAVE_AD_W              .EQU    $60
I2C_STA_SLAVE_AL_AD_W           .EQU    $68
I2C_STA_SDA_STUCK               .EQU    $70
I2C_STA_SCL_STUCK               .EQU    $78
I2C_STA_SLAVE_DATA_RX_ACK       .EQU    $80
I2C_STA_SLAVE_DATA_RX_NAK       .EQU    $88
I2C_STA_SLAVE_STOP_OR_RESTART   .EQU    $A0
I2C_STA_SLAVE_AD_R              .EQU    $A8
I2C_STA_SLAVE_AL_AD_R           .EQU    $B0
I2C_STA_SLAVE_DATA_TX_ACK       .EQU    $B8
I2C_STA_SLAVE_DATA_TX_NAK       .EQU    $C0
I2C_STA_SLAVE_LST_TX_ACK        .EQU    $C8
I2C_STA_SLAVE_GC                .EQU    $D0
I2C_STA_SLAVE_GC_AL             .EQU    $D8
I2C_STA_SLAVE_GC_RX_ACK         .EQU    $E0
I2C_STA_SLAVE_GC_RX_NAK         .EQU    $E8
I2C_STA_IDLE                    .EQU    $F8 ;_IDLE is unused, so
I2C_STA_ILLEGAL_ICOUNT          .EQU    $FC ;_ILLEGAL_ICOUNT can be $F8 case

;   Bits in PCA_CON

I2C_CON_AA      .EQU    $80 ; Assert Acknowledge
I2C_CON_ENSIO   .EQU    $40 ; Enable, change only when I2C bus idle.
I2C_CON_STA     .EQU    $20 ; Start (Restart)
I2C_CON_STO     .EQU    $10 ; Stop
I2C_CON_SI      .EQU    $08 ; Serial Interrupt
I2C_CON_MODE    .EQU    $01 ; Mode, 1 = buffered, 0 = byte

;   Bits in PCA_CON Echo, for CPU control
I2C_CON_ECHO_BUS_STOP       .EQU    $10 ; We are finished the sentence
I2C_CON_ECHO_SI             .EQU    $08 ; Serial Interrupt Received
I2C_CON_ECHO_BUS_RESTART    .EQU    $04 ; Bus Restart Requested
I2C_CON_ECHO_BUS_ILLEGAL    .EQU    $02 ; Unexpected Bus Response

;   Bits in PCA_ICOUNT
     
I2C_ICOUNT_LB   .EQU    $80 ; Last Byte control bit
                            ; LB bit is only used for Receiver Buffered modes

;   BITS in PCA_ITO

I2C_ITO_TE      .EQU    $80 ; Time-Out Enable control bit 

;  Bits in PCA_IMODE

I2C_IMODE_STD   .EQU    $00 ; Standard mode
I2C_IMODE_FAST  .EQU    $01 ; Fast mode
I2C_IMODE_FASTP .EQU    $02 ; Fast Plus mode
I2C_IMODE_TURBO .EQU    $03 ; Turbo mode

I2C_IMODE_CR    .EQU    $07 ; Clock Rate (MASK)

;==============================================================================
;
; VARIABLES SECTION
;

i2c1RxInPtr     .EQU    Z180_VECTOR_BASE+Z180_VECTOR_SIZE+$30
i2c1RxOutPtr    .EQU    i2c1RxInPtr+2
i2c1TxOutPtr    .EQU    i2c1RxOutPtr+2
i2c1RxBufUsed   .EQU    i2c1TxOutPtr+2

i2c1StatusEcho  .EQU    i2c1RxBufUsed+1
i2c1ControlEcho .EQU    i2c1StatusEcho+1
i2c1SlaveAddr   .EQU    i2c1ControlEcho+1
i2c1SentenceLgth .EQU   i2c1SlaveAddr+1

i2c2RxInPtr     .EQU    Z180_VECTOR_BASE+Z180_VECTOR_SIZE+$40
i2c2RxOutPtr    .EQU    i2c2RxInPtr+2
i2c2TxOutPtr    .EQU    i2c2RxOutPtr+2
i2c2RxBufUsed   .EQU    i2c2TxOutPtr+2

i2c2StatusEcho  .EQU    i2c2RxBufUsed+1
i2c2ControlEcho .EQU    i2c2StatusEcho+1
i2c2SlaveAddr   .EQU    i2c2ControlEcho+1
i2c2SentenceLgth .EQU   i2c2SlaveAddr+1

I2C_BUFFER_SIZE .EQU    $FF ; PCA9665 has 68 Byte Tx/Rx hardware buffer
                            ; sentences greater than 68 bytes must be
                            ; done 64 bytes at a time (max 256 bytes)

;I2C 256 byte Rx buffer origin (Tx write direct to interface)

i2c1RxBuffer     .EQU    APUPTRBuf+APU_PTR_BUFSIZE+1
i2c2RxBuffer     .EQU    i2c1RxBuffer+I2C_BUFFER_SIZE+1

;==============================================================================
;
; CODE SECTION
;

;------------------------------------------------------------------------------
; MACROS - for where speed is of the essence, and we don't compute the address

    ;Do a read from the indirect registers
    ;destroys BC
    ;output A =  byte read

#DEFINE i2c_read_indirect_m(DEVICE,IREGISTER)   ld b, DEVICE
#DEFCONT                                    \   ld c, PCA_INDPTR
#DEFCONT                                    \   ld a, IREGISTER
#DEFCONT                                    \   out (c), a
#DEFCONT                                    \   ld c, PCA_IND
#DEFCONT                                    \   in a, (c)

    ;Do a write to the indirect registers
    ;input A  =  byte to write
    ;destroys BC

#DEFINE i2c_write_indirect_m(DEVICE,IREGISTER)  push af
#DEFCONT                                    \   ld b, DEVICE
#DEFCONT                                    \   ld c, PCA_INDPTR
#DEFCONT                                    \   ld a, IREGISTER
#DEFCONT                                    \   out (c), a
#DEFCONT                                    \   ld c, PCA_IND
#DEFCONT                                    \   pop af
#DEFCONT                                    \   out (c), a

    ;Do a read from the direct registers
    ;destroys BC    
    ;output A =  byte read

#DEFINE i2c_read_direct_m(DEVICE,REGISTER)      ld b, DEVICE
#DEFCONT                                    \   ld c, REGISTER
#DEFCONT                                    \   in a, (c)

    ;Do a write to the direct registers
    ;input A  =  byte to write
    ;destroys BC

#DEFINE i2c_write_direct_m(DEVICE,REGISTER)     ld b, DEVICE
#DEFCONT                                    \   ld c, REGISTER
#DEFCONT                                    \   out (c), a

;------------------------------------------------------------------------------
; Routines that talk with the I2C interface, these should be called by
; the main program.

    .module driver_api
    .org location

;------------------------------------------------------------------------------
; API routines - functions for the user

    ;Initialise a PCA9665 device
    ;input A  =  device address, PCA1_ADDR or PCA2_ADDR
pca_initialise:
    tst PCA1_ADDR|PCA2_ADDR
    ret z                   ;no device address match, so exit
    and PCA1_ADDR|PCA2_ADDR
    or PCA_CON              ;prepare device and register address
    ld c, a
    ld a, I2C_CON_ENSIO     ;enable the PCA9665 device
    jp i2c_write_direct

    ;Reset a PCA9665 device
    ;input A  =  device address, PCA1_ADDR or PCA2_ADDR
    ;write a $A5 followed by $5A to the IPRESET register

pca_software_reset:
    tst PCA1_ADDR|PCA2_ADDR
    ret z                   ;no device address match, so exit
    and PCA1_ADDR|PCA2_ADDR
    or PCA_IPRESET          ;prepare device and register address
    ld c, a
    ld a, $A5               ;reset the PCA9665 device
    call i2c_write_indirect
    ld a, $5A               ;reset the PCA9665 device
    jp i2c_write_indirect

    ;attach an interrupt relevant for the specific device
    ;input HL = address of the interrupt service routine
    ;input A  = device address, PCA1_ADDR or PCA2_ADDR

i2c_interrupt_attach:
    tst PCA1_ADDR|PCA2_ADDR
    ret z                   ;no device address match, so exit
    cp PCA2_ADDR
    jr z, i2c_int_at2    
    ld (INT_INT1_ADDR), hl  ;load the address of the APU INT1 routine
    ret
    
i2c_int_at2:
    ld (INT_INT2_ADDR), hl  ;load the address of the APU INT2 routine
    ret


;------------------------------------------------------------------------------
; i2c1_read_buffer

    .module i2c1RdBuff

;   Read from the PCA1 I2C Interface, using Buffer Mode
;   parameters passed in registers
;   HL = pointer to data to store, uint8_t *dp
;   B  = length of sentence, uint8_t i2c1SentenceLgth
;   C  = address of slave device, uint8_t slave_addr
;   A  = restart flag (continue with additional data), uint8_t restart_flag
i2c1_read_buffer:
    push de
    push af
    ex de, hl                   ;move the data pointer to de

    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ENSIO
    and (hl)
    jr nz, i2c1_read_buffer_ex ;return if the I2C interface is busy

    ld hl, i2c1SentenceLgth
    ld a, (hl)
    and a
    jr nz, i2c1_read_buffer_ex ;return if the I2C interface is busy
    
    ld a, 68                    ;maximum sentence
    cp b                        ;check the sentence
    jr c, i2c1_read_buffer_ex   ;return if the sentence is too long
    
    ld a, b                     ;check for zero
    and a                       ;check the sentence
    jr z, i2c1_read_buffer_ex   ;return if the sentence zero length
    
    ld (i2c1SentenceLgth), b    ;store the sentence length
    ld (i2c1SlaveAddr), c       ;store the slave address
    ex de, hl                   ;recover data pointer
    ld (i2c1RxInPtr), hl        ;store the data pointer
    pop af
    or a                        ;is restart flag set?
    ld a, I2C_CON_ECHO_BUS_RESTART ;set restart flag, and clear all other flags
    jr nz, i2c1_read_buffer2
    xor a
i2c1_read_buffer2:
    or I2C_CON_ENSIO
    ld (i2c1ControlEcho), a     ;store enable and restart flag in the control echo

    ld a, I2C_CON_ENSIO
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)   ;enable the I2C interface, wait 550ns
    nop
    ld a, I2C_CON_ENSIO|I2C_CON_STA|I2C_CON_MODE
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)   ; set the interface enable, STA, buff MODE
    
    ld hl, i2c1ControlEcho    
i2c1_read_buffer_wait:           ;busy wait loop
    ld a, (hl)
    tst I2C_CON_ECHO_BUS_STOP
    jr z, i2c1_read_buffer_wait  ;if the bus is still not stopped, then wait till it is

    ld hl, i2c1RxBufUsed
    ld b, (hl)
    ld c, PCA1_ADDR|PCA_DAT
    ld hl, (i2c1RxInPtr)
    call i2c_read_burst

    ld hl, i2c1ControlEcho
    tst I2C_CON_ECHO_BUS_RESTART
    jr nz, i2c1_read_buffer_ex2  ;just exit

    ld a, I2C_CON_ENSIO|I2C_CON_STO         ;set the interface to STOP
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    jr i2c1_read_buffer_ex2      ;just exit

i2c1_read_buffer_ex:             ;return if the I2C interface is busy
    ex de, hl
    pop af
i2c1_read_buffer_ex2:            ;normal return
    pop de
    ret
 

;------------------------------------------------------------------------------
; interrupt service routine - direct to hardware - i2c_int1_read_buffer

i2c_int1_read_buffer:
    push af
    push bc
    push de
    push hl

    i2c_read_direct_m(PCA1_ADDR,PCA_STA)   ;we need the status
    ld hl, i2c1StatusEcho
    ld (hl), a              ;echo the status
    srl a                   ;get the status from status register for switch
    srl a                   ;shift right to make word offset case addresses
    ld l, a
    ld h, $0
    ld de, i2c_int1_read_buffer_switch
    add hl, de              ;get create the address for the switch
    
    ld de, i2c_int1_read_buffer_end
    push de                 ;prepare a return address for the switch

    ld a, (hl)              ;load the address for our switch case
    inc hl
    ld h, (hl)
    ld l, a
    jp (hl)                 ;make the switch

i2c_int1_read_buffer_end:
    pop hl                  ;return here to clean up the interrupt
    pop de
    pop bc
    pop af
    ret

_MASTER_START_TX:
_MASTER_RESTART_TX:
    ld hl, i2c1SlaveAddr    ; get address of slave we're reading
    ld a, (hl)
    or $01
    i2c_write_direct_m(PCA1_ADDR,PCA_DAT)
    ld hl, i2c1SentenceLgth
    ld a, (hl)
    or I2C_ICOUNT_LB
    i2c_write_indirect_m(PCA1_ADDR,PCA_ICOUNT)
    ld a, I2C_CON_ENSIO|I2C_CON_MODE
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    ret

_MASTER_DATA_R_ACK:                         ;data received
_MASTER_SLA_R_ACK:                          ;SLA+R transmitted
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP             ;sentence complete, we're done    
    or (hl)
    ld (hl), a
    ret

_MASTER_DATA_R_NAK:
    i2c_read_indirect_m(PCA1_ADDR,PCA_ICOUNT)
    and ~I2C_ICOUNT_LB
    ld hl, i2c1RxBufUsed
    ld (hl), a

    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP             ;sentence complete, we're done    
    or (hl)
    ld (hl), a
    ret

_MASTER_SLA_R_NAK:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP             ;sentence complete, we're done    
    or (hl)
    ld (hl), a
    ret

_ILGL_START_STOP:
_ILGL_ICOUNT:
_SCL_STUCK:
    jp pca_software_reset
    

_MASTER_SLA_W_ACK:
_MASTER_SLA_W_NAK:
_MASTER_DATA_W_ACK:
_MASTER_DATA_W_NAK:
_MASTER_ARB_LOST:
_SLAVE_AD_W:
_SLAVE_AL_AD_W:
_SDA_STUCK:
_SLAVE_DATA_RX_ACK:
_SLAVE_DATA_RX_NAK:
_SLAVE_STOP_RESRT:
_SLAVE_AD_R:
_SLAVE_AL_AD_R:
_SLAVE_DATA_TX_ACK:
_SLAVE_DATA_TX_NAK:
_SLAVE_LST_TX_ACK:
_SLAVE_GC:
_SLAVE_GC_AL:                       ;bus should be released for other master
_SLAVE_GC_RX_ACK:
_SLAVE_GC_RX_NAK:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_ILLEGAL  ;unexpected bus status or error   
    or (hl)
    ld (hl), a
    ret

i2c_int1_read_buffer_switch:
    .dw _ILGL_START_STOP
    .dw _MASTER_START_TX
    .dw _MASTER_RESTART_TX
    .dw _MASTER_SLA_W_ACK
    .dw _MASTER_SLA_W_NAK
    .dw _MASTER_DATA_W_ACK
    .dw _MASTER_DATA_W_NAK
    .dw _MASTER_ARB_LOST
    .dw _MASTER_SLA_R_ACK
    .dw _MASTER_SLA_R_NAK
    .dw _MASTER_DATA_R_ACK
    .dw _MASTER_DATA_R_NAK
    .dw _SLAVE_AD_W
    .dw _SLAVE_AL_AD_W
    .dw _SDA_STUCK
    .dw _SCL_STUCK
    .dw _SLAVE_DATA_RX_ACK
    .dw _SLAVE_DATA_RX_NAK
    .dw _SLAVE_STOP_RESRT
    .dw _SLAVE_AD_R
    .dw _SLAVE_AL_AD_R
    .dw _SLAVE_DATA_TX_ACK
    .dw _SLAVE_DATA_TX_NAK
    .dw _SLAVE_LST_TX_ACK
    .dw _SLAVE_GC
    .dw _SLAVE_GC_AL
    .dw _SLAVE_GC_RX_ACK
    .dw _SLAVE_GC_RX_NAK
    .dw _ILGL_ICOUNT                ;_ILGL_ICOUNT can be $F8 _IDLE case

;------------------------------------------------------------------------------
; i2c1_write_buffer

    .module i2c1WrBuff

;   Write to the PCA1 I2C Interface, using Buffer Mode
;   parameters passed in registers
;   HL = pointer to data to transmit, uint8_t *dp
;   B  = length of sentence, uint8_t i2c1SentenceLgth
;   C  = address of slave device, uint8_t slave_addr
;   A  = restart flag (continue with additional data), uint8_t restart_flag
i2c1_write_buffer:
    push de
    push af
    ex de, hl                   ;move the data pointer to de

    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ENSIO
    and (hl)
    jr nz, i2c1_write_buffer_ex ;return if the I2C interface is busy

    ld hl, i2c1SentenceLgth
    ld a, (hl)
    and a
    jr nz, i2c1_write_buffer_ex ;return if the I2C interface is busy
    
    ld a, 67                    ;maximum sentence
    cp b                        ;check the sentence
    jr c, i2c1_write_buffer_ex  ;return if the sentence is too long
    
    ld (i2c1SentenceLgth), b    ;store the sentence length
    ld (i2c1SlaveAddr), c       ;store the slave address
    ex de, hl                   ;recover data pointer
    ld (i2c1TxOutPtr), hl       ;store the data pointer
    pop af
    or a                        ;is restart flag set?
    ld a, I2C_CON_ECHO_BUS_RESTART ;set restart flag, and clear all other flags
    jr nz, i2c1_write_buffer2
    xor a
i2c1_write_buffer2:
    or I2C_CON_ENSIO
    ld (i2c1ControlEcho), a     ;store enable and restart flag in the control echo

    ld a, I2C_CON_ENSIO
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)   ;enable the I2C interface, wait 550ns
    nop
    ld a, I2C_CON_ENSIO|I2C_CON_STA|I2C_CON_MODE
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)   ; set the interface enable, STA, buff MODE
    
    ld hl, i2c1ControlEcho    
i2c1_write_buffer_wait:           ;busy wait loop
    ld a, (hl)
    tst I2C_CON_ECHO_BUS_STOP
    jr z, i2c1_write_buffer_wait  ;if the bus is still not stopped, then wait till it is
    
    tst I2C_CON_ECHO_BUS_RESTART
    jr nz, i2c1_write_buffer_ex2  ;just exit

    ld a, I2C_CON_ENSIO|I2C_CON_STO         ;set the interface to STOP
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    jr i2c1_write_buffer_ex2      ;just exit

i2c1_write_buffer_ex:             ;return if the I2C interface is busy
    ex de, hl
    pop af
i2c1_write_buffer_ex2:            ;normal return
    pop de
    ret
 
;------------------------------------------------------------------------------
; interrupt service routine - direct to hardware - i2c_int1_write_buffer

i2c_int1_write_buffer:
    push af
    push bc
    push de
    push hl

    i2c_read_direct_m(PCA1_ADDR,PCA_STA)   ;we need the status
    ld hl, i2c1StatusEcho
    ld (hl), a              ;echo the status
    srl a                   ;get the status from status register for switch
    srl a                   ;shift right to make word offset case addresses
    ld l, a
    ld h, $0
    ld de, i2c_int1_write_buffer_switch
    add hl, de              ;get create the address for the switch
    
    ld de, i2c_int1_write_buffer_end
    push de                 ;prepare a return address for the switch

    ld a, (hl)              ;load the address for our switch case
    inc hl
    ld h, (hl)
    ld l, a
    jp (hl)                 ;make the switch

i2c_int1_write_buffer_end:
    pop hl                  ;return here to clean up the interrupt
    pop de
    pop bc
    pop af
    ret

_MASTER_START_TX:
_MASTER_RESTART_TX:
    ld hl, i2c1SlaveAddr    ; get address of slave we're writing
    ld a, (hl)
    and $FE
    i2c_write_direct_m(PCA1_ADDR,PCA_DAT)
    ld hl, i2c1SentenceLgth
    ld a, (hl)
    inc a
    i2c_write_indirect_m(PCA1_ADDR,PCA_ICOUNT)
    ld hl, i2c1SentenceLgth
    ld b, (hl)
    ld c, PCA1_ADDR|PCA_DAT
    ld hl, (i2c1TxOutPtr)
    call i2c_write_burst
    ld (i2c1TxOutPtr), hl
    ld hl, i2c1SentenceLgth
    ld b, (hl)
    ld hl, i2c1TxBufUsed
    ld a, (hl)
    sub b
    ld (hl), a
    ld a, I2C_CON_ENSIO|I2C_CON_MODE
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    ret

_MASTER_DATA_W_ACK:                 ;data transmitted
_MASTER_SLA_W_ACK:                  ;SLA+W transmitted
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP     ;sentence complete, we're done    
    or (hl)
    ld (hl), a
    ret

_MASTER_DATA_W_NAK:
_MASTER_SLA_W_NAK:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP     ;sentence complete, we're done    
    or (hl)
    ld (hl), a
    ret

_ILGL_START_STOP:
_ILGL_ICOUNT:
_SCL_STUCK:
    jp pca_software_reset

_MASTER_ARB_LOST:
_MASTER_SLA_R_ACK:
_MASTER_SLA_R_NAK:
_MASTER_DATA_R_ACK:
_MASTER_DATA_R_NAK
_SLAVE_AD_W:
_SLAVE_AL_AD_W:
_SDA_STUCK:
_SLAVE_DATA_RX_ACK:
_SLAVE_DATA_RX_NAK:
_SLAVE_STOP_RESRT:
_SLAVE_AD_R:
_SLAVE_AL_AD_R:
_SLAVE_DATA_TX_ACK:
_SLAVE_DATA_TX_NAK:
_SLAVE_LST_TX_ACK:
_SLAVE_GC:
_SLAVE_GC_AL:                       ;bus should be released for other master
_SLAVE_GC_RX_ACK:
_SLAVE_GC_RX_NAK:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_ILLEGAL  ;unexpected bus status or error
    or (hl)
    ld (hl), a
    ret

i2c_int1_write_buffer_switch:
    .dw _ILGL_START_STOP
    .dw _MASTER_START_TX
    .dw _MASTER_RESTART_TX
    .dw _MASTER_SLA_W_ACK
    .dw _MASTER_SLA_W_NAK
    .dw _MASTER_DATA_W_ACK
    .dw _MASTER_DATA_W_NAK
    .dw _MASTER_ARB_LOST
    .dw _MASTER_SLA_R_ACK
    .dw _MASTER_SLA_R_NAK
    .dw _MASTER_DATA_R_ACK
    .dw _MASTER_DATA_R_NAK
    .dw _SLAVE_AD_W
    .dw _SLAVE_AL_AD_W
    .dw _SDA_STUCK
    .dw _SCL_STUCK
    .dw _SLAVE_DATA_RX_ACK
    .dw _SLAVE_DATA_RX_NAK
    .dw _SLAVE_STOP_RESRT
    .dw _SLAVE_AD_R
    .dw _SLAVE_AL_AD_R
    .dw _SLAVE_DATA_TX_ACK
    .dw _SLAVE_DATA_TX_NAK
    .dw _SLAVE_LST_TX_ACK
    .dw _SLAVE_GC
    .dw _SLAVE_GC_AL
    .dw _SLAVE_GC_RX_ACK
    .dw _SLAVE_GC_RX_NAK
    .dw _ILGL_ICOUNT        ;_ILGL_ICOUNT can be $F8 _IDLE case

;------------------------------------------------------------------------------
; interrupt service routine - direct to hardware - i2c_int1_read_byte

    .module i2c1RdByte

i2c_int1_read_byte:
    push af
    push bc
    push de
    push hl

    i2c_read_direct_m(PCA1_ADDR,PCA_STA)   ;we need the status
    ld hl, i2c1StatusEcho
    ld (hl), a              ;echo the status
    srl a                   ;get the status from status register for switch
    srl a                   ;shift right to make word offset case addresses
    ld l, a
    ld h, $0
    ld de, i2c_int1_read_byte_switch
    add hl, de              ;get create the address for the switch
    
    ld de, i2c_int1_read_byte_end
    push de                 ;prepare a return address for the switch

    ld a, (hl)              ;load the address for our switch case
    inc hl
    ld h, (hl)
    ld l, a
    jp (hl)                 ;make the switch

i2c_int1_read_byte_end:
    pop hl                  ;return here to clean up the interrupt
    pop de
    pop bc
    pop af
    ret

_MASTER_START_TX:
_MASTER_RESTART_TX:
    ld hl, i2c1SlaveAddr    ; get address of slave we're reading
    ld a, (hl)
    or $01
    i2c_write_direct_m(PCA1_ADDR,PCA_DAT)
    ld a, I2C_CON_ENSIO
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    ret
    
_MASTER_DATA_R_NAK:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP             ;sentence complete, we're done    
    or (hl)
    ld (hl), a                              ;then fall through
_MASTER_DATA_R_ACK:                         ;data received
    i2c_read_direct_m(PCA1_ADDR,PCA_DAT)    ;get the byte
    ld hl, (i2c1RxInPtr)                    ;get the pointer to where we poke                
    ld (hl), a                              ;write the Rx byte to the i2c1RxInPtr target
    inc l                                   ;move the Rx pointer low byte along, 0xFF rollover
    ld (i2c1RxInPtr), hl                    ;write where the next byte should be poked

    ld hl, i2c1RxBufUsed
    inc (hl)                                ;atomically increment Rx buffer count
    
    ld hl, i2c1SentenceLgth                 ;decrement the remaining sentence length
    dec (hl)
    
_MASTER_SLA_R_ACK:                          ;SLA+R transmitted
    ld hl, i2c1SentenceLgth
    ld a, (hl)
    or a
    ld hl, i2c1ControlEcho    
    jr nz, _MASTER_SLA_R_ACK2
    ld a, I2C_CON_ECHO_BUS_STOP             ;sentence complete, we're done    
    or (hl)
    ld (hl), a
_MASTER_SLA_R_ACK2:
    ld a, (hl)                              ;get the status
    and I2C_CON_ECHO_BUS_STOP               ;check whether done (non zero).
    ret nz
    
    ld hl, i2c1SentenceLgth                 ;load the the remaining sentence length
    ld a, (hl)
    cp 1
    jr nz, _MASTER_SLA_R_ACK3               ;sentence remaining is greater than 1 byte
    ld a, I2C_CON_ENSIO
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    ret
    
_MASTER_SLA_R_ACK3:
    ld a, I2C_CON_ENSIO|I2C_CON_AA
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    ret
        
_MASTER_SLA_R_NAK:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP             ;sentence complete, we're done    
    or (hl)
    ld (hl), a
    ret

_ILGL_START_STOP:
_MASTER_SLA_W_ACK:
_MASTER_SLA_W_NAK:
_MASTER_DATA_W_ACK:
_MASTER_DATA_W_NAK:
_MASTER_ARB_LOST:
_SLAVE_AD_W:
_SLAVE_AL_AD_W:
_SDA_STUCK:
_SCL_STUCK:
_SLAVE_DATA_RX_ACK:
_SLAVE_DATA_RX_NAK:
_SLAVE_STOP_RESRT:
_SLAVE_AD_R:
_SLAVE_AL_AD_R:
_SLAVE_DATA_TX_ACK:
_SLAVE_DATA_TX_NAK:
_SLAVE_LST_TX_ACK:
_SLAVE_GC:
_SLAVE_GC_AL:                       ;bus should be released for other master
_SLAVE_GC_RX_ACK:
_SLAVE_GC_RX_NAK:
_ILGL_ICOUNT:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_ILLEGAL  ;unexpected bus status or error
    or (hl)
    ld (hl), a
    ret

i2c_int1_read_byte_switch:
    .dw _ILGL_START_STOP
    .dw _MASTER_START_TX
    .dw _MASTER_RESTART_TX
    .dw _MASTER_SLA_W_ACK
    .dw _MASTER_SLA_W_NAK
    .dw _MASTER_DATA_W_ACK
    .dw _MASTER_DATA_W_NAK
    .dw _MASTER_ARB_LOST
    .dw _MASTER_SLA_R_ACK
    .dw _MASTER_SLA_R_NAK
    .dw _MASTER_DATA_R_ACK
    .dw _MASTER_DATA_R_NAK
    .dw _SLAVE_AD_W
    .dw _SLAVE_AL_AD_W
    .dw _SDA_STUCK
    .dw _SCL_STUCK
    .dw _SLAVE_DATA_RX_ACK
    .dw _SLAVE_DATA_RX_NAK
    .dw _SLAVE_STOP_RESRT
    .dw _SLAVE_AD_R
    .dw _SLAVE_AL_AD_R
    .dw _SLAVE_DATA_TX_ACK
    .dw _SLAVE_DATA_TX_NAK
    .dw _SLAVE_LST_TX_ACK
    .dw _SLAVE_GC
    .dw _SLAVE_GC_AL
    .dw _SLAVE_GC_RX_ACK
    .dw _SLAVE_GC_RX_NAK
    .dw _ILGL_ICOUNT        ;_ILGL_ICOUNT can be $F8 _IDLE case

;------------------------------------------------------------------------------
; i2c1_write_byte

    .module i2c1WrByte

;   Write to the PCA1 I2C Interface, using Byte Mode
;   parameters passed in registers
;   HL = pointer to data to transmit, uint8_t *dp
;   B  = length of sentence, uint8_t i2c1SentenceLgth
;   C  = address of slave device, uint8_t slave_addr
;   A  = restart flag (continue with additional data), uint8_t restart_flag
i2c1_write_byte:
    push de
    push af
    ex de, hl                   ;move the data pointer to de

    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ENSIO
    and (hl)
    jr nz, i2c1_write_byte_ex   ;return if the I2C interface is busy

    ld hl, i2c1SentenceLgth
    ld a, (hl)
    and a
    jr nz, i2c1_write_byte_ex   ;return if the I2C interface is busy
    
    ld (i2c1SentenceLgth), b    ;store the sentence length
    ld (i2c1SlaveAddr), c       ;store the slave address
    ex de, hl                   ;recover data pointer
    ld (i2c1TxOutPtr), hl       ;store the data pointer
    pop af
    or a                        ;is restart flag set?
    ld a, I2C_CON_ECHO_BUS_RESTART ;set restart flag, and clear all other flags
    jr nz, i2c1_write_byte2
    xor a
i2c1_write_byte2:
    or I2C_CON_ENSIO
    ld (i2c1ControlEcho), a     ;store enable and restart flag in the control echo

    ld a, I2C_CON_ENSIO
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)   ;enable the I2C interface, wait 550ns
    nop
    ld a, I2C_CON_ENSIO|I2C_CON_STA
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)   ; set the interface enable and STA bit
    
    ld hl, i2c1ControlEcho    
i2c1_write_byte_wait:           ;busy wait loop
    ld a, (hl)
    tst I2C_CON_ECHO_BUS_STOP
    jr z, i2c1_write_byte_wait  ;if the bus is still not stopped, then wait till it is
    
    tst I2C_CON_ECHO_BUS_RESTART
    jr nz, i2c1_write_byte_ex2  ;just exit

    ld a, I2C_CON_ENSIO|I2C_CON_STO         ;set the interface to STOP
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    jr i2c1_write_byte_ex2      ;just exit

i2c1_write_byte_ex:             ;return if the I2C interface is busy
    ex de, hl
    pop af
i2c1_write_byte_ex2:            ;normal return
    pop de
    ret 

;------------------------------------------------------------------------------
; interrupt service routine - direct to hardware - i2c_int1_write_byte

i2c_int1_write_byte:
    push af
    push bc
    push de
    push hl

    i2c_read_direct_m(PCA1_ADDR,PCA_STA)   ;we need the status
    ld hl, i2c1StatusEcho
    ld (hl), a              ;echo the status
    srl a                   ;get the status from status register for switch
    srl a                   ;shift right to make word offset case addresses
    ld l, a
    ld h, $0
    ld de, i2c_int1_write_byte_switch
    add hl, de              ;get create the address for the switch
    
    ld de, i2c_int1_write_byte_end
    push de                 ;prepare a return address for the switch

    ld a, (hl)              ;load the address for our switch case
    inc hl
    ld h, (hl)
    ld l, a
    jp (hl)                 ;make the switch

i2c_int1_write_byte_end:
    pop hl                  ;return here to clean up the interrupt
    pop de
    pop bc
    pop af
    ret

_MASTER_START_TX:
_MASTER_RESTART_TX:
    ld hl, i2c1SlaveAddr            ; get address of slave we're writing
    ld a, (hl)
    and $FE
    i2c_write_direct_m(PCA1_ADDR,PCA_DAT)
    ld a, I2C_CON_ENSIO
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    ret

_MASTER_DATA_W_ACK:                 ;data transmitted
    ld hl, i2c1SentenceLgth         ;decrement the remaining sentence length
    dec (hl)
_MASTER_SLA_W_ACK:                  ;SLA+W transmitted
    ld hl, i2c1SentenceLgth
    ld a, (hl)
    or a
    jp nz, _MASTER_SLA_W_ACK2
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP     ;sentence complete, we're done    
    or (hl)
    ld (hl), a
    ret

_MASTER_SLA_W_ACK2:
    ld hl, (i2c1TxOutPtr)
    ld a, (hl)
    i2c_write_direct_m(PCA1_ADDR,PCA_DAT)  ;write the byte
    inc hl
    ld (i2c1TxOutPtr), hl
    ld a, I2C_CON_ENSIO
    i2c_write_direct_m(PCA1_ADDR,PCA_CON)
    ret

_MASTER_SLA_W_NAK:
_MASTER_DATA_W_NAK:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_STOP     ;sentence complete, we're done    
    or (hl)
    ld (hl), a
    ret

_ILGL_START_STOP:
_MASTER_ARB_LOST:
_MASTER_SLA_R_ACK:
_MASTER_SLA_R_NAK:
_MASTER_DATA_R_ACK:
_MASTER_DATA_R_NAK
_SLAVE_AD_W:
_SLAVE_AL_AD_W:
_SDA_STUCK:
_SCL_STUCK:
_SLAVE_DATA_RX_ACK:
_SLAVE_DATA_RX_NAK:
_SLAVE_STOP_RESRT:
_SLAVE_AD_R:
_SLAVE_AL_AD_R:
_SLAVE_DATA_TX_ACK:
_SLAVE_DATA_TX_NAK:
_SLAVE_LST_TX_ACK:
_SLAVE_GC:
_SLAVE_GC_AL:                       ;bus should be released for other master
_SLAVE_GC_RX_ACK:
_SLAVE_GC_RX_NAK:
_ILGL_ICOUNT:
    ld hl, i2c1ControlEcho
    ld a, I2C_CON_ECHO_BUS_ILLEGAL  ;unexpected bus status or error    
    or (hl)
    ld (hl), a
    ret

i2c_int1_write_byte_switch:
    .dw _ILGL_START_STOP
    .dw _MASTER_START_TX
    .dw _MASTER_RESTART_TX
    .dw _MASTER_SLA_W_ACK
    .dw _MASTER_SLA_W_NAK
    .dw _MASTER_DATA_W_ACK
    .dw _MASTER_DATA_W_NAK
    .dw _MASTER_ARB_LOST
    .dw _MASTER_SLA_R_ACK
    .dw _MASTER_SLA_R_NAK
    .dw _MASTER_DATA_R_ACK
    .dw _MASTER_DATA_R_NAK
    .dw _SLAVE_AD_W
    .dw _SLAVE_AL_AD_W
    .dw _SDA_STUCK
    .dw _SCL_STUCK
    .dw _SLAVE_DATA_RX_ACK
    .dw _SLAVE_DATA_RX_NAK
    .dw _SLAVE_STOP_RESRT
    .dw _SLAVE_AD_R
    .dw _SLAVE_AL_AD_R
    .dw _SLAVE_DATA_TX_ACK
    .dw _SLAVE_DATA_TX_NAK
    .dw _SLAVE_LST_TX_ACK
    .dw _SLAVE_GC
    .dw _SLAVE_GC_AL
    .dw _SLAVE_GC_RX_ACK
    .dw _SLAVE_GC_RX_NAK
    .dw _ILGL_ICOUNT    ;_ILGL_ICOUNT can be $F8 _IDLE case

;------------------------------------------------------------------------------
; low level routines - direct to hardware

    .module driver_internal

    ;Enable the I2C interrupt for each PCA9665 device
    ;Configuring the interrupt is done in the i2c_interrupt_attach function
    ;input A  =  device address, PCA1_ADDR or PCA2_ADDR

i2c_interrupt_enable:
;    tst PCA1_ADDR|PCA2_ADDR
;    ret z               ;no device address match, so exit
    push bc
    in0 c, (ITC)        ;get INT/TRAP Control Register (ITC)
    cp PCA2_ADDR
    ld a, c
    jr z, i2c_int_en2    
    or ITC_ITE1         ;mask in INT1
    jr i2c_int_en1
i2c_int_en2:
    or ITC_ITE2         ;mask in INT2
i2c_int_en1:
    out0 (ITC), a       ;enable external interrupt
    pop bc
    ret

    ;Disable the I2C interrupt for each PCA9665 device
    ;Configuring the interrupt is done in the i2c_interrupt_attach function
    ;input A  =  device address, PCA1_ADDR or PCA2_ADDR

i2c_interrupt_disable:
;    tst PCA1_ADDR|PCA2_ADDR
;    ret z               ;no device address match, so exit
    push bc
    in0 c, (ITC)        ;get INT/TRAP Control Register (ITC)
    cp PCA2_ADDR
    ld a, c
    jr z, i2c_int_de2
    and ~ITC_ITE1       ;mask out INT1
    jr i2c_int_de1
i2c_int_de2:
    and  ~ITC_ITE2      ;mask out INT2
i2c_int_de1:
    out0 (ITC), a       ;disable external interrupt
    pop bc   
    ret

    ;Do a burst read from the direct registers
    ;input B  =  number of bytes to read < $FF
    ;input C  =  device addr | direct register address ($DR)
    ;input HL =  starting adddress of 256 byte output buffer
    ;output HL = finishing address
    ;FIXME do this with DMA
    
i2c_read_burst:
    push af
    push de
    ld d, h
    ld a, b             ;keep iterative count in A
i2c_rd_bst:
    ld b, c             ;prepare device and register address
                        ;lower address bits (0x1F) of B irrelevant
                        ;upper address bits (0xFC) of C irrelevant
    ld h, d             ;wrap the buffer address MSB                        
    ini                 ;read the byte (HL++)
    dec a               ;keep iterative count in A
    jr nz, i2c_rd_bst
    pop de
    pop af
    ret

    ;Do a burst write to the direct registers
    ;input B  =  number of bytes to write < $FF
    ;input C  =  device addr | direct register address ($DR)
    ;input HL =  starting adddress of 256 byte input buffer
    ;output HL = finishing address
    ;FIXME do this with DMA
    
i2c_write_burst:
    push af
    push de
    ld d, h
    ld a, b             ;keep iterative count in A
i2c_wr_bst:
    ld b, c             ;prepare device and register address
                        ;lower address bits (0x1F) of B irrelevant
                        ;upper address bits (0xFC) of C irrelevant
    ld h, d             ;wrap the buffer address MSB                        
    outi                ;write the byte (HL++)
    dec a               ;keep iterative count in A
    jr nz, i2c_wr_bst
    pop de
    pop af
    ret

    ;Do a read from the indirect registers
    ;input C  =  device addr | indirect register address ($DR)
    ;output A =  byte read
    ;preserves device and register address in BC
    
i2c_read_indirect:
    push bc             ;preserve the device and register address
    ld b, c             ;prepare device and register address
                        ;lower address bits (0x1F) of B irrelevant
    ld a, c             ;prepare indirect address in A
    and $07             ;ensure upper bits are zero
    ld c, PCA_INDPTR
    out (c), a          ;write the indirect address to the PCA_INDPTR
    ld c, PCA_IND       ;prepare device and indirect register address
                        ;lower address bits (0x1F) of B irrelevant
    in a, (c)           ;get the byte from the indirect register
    pop bc
    ret

    ;Do a write to the indirect registers
    ;input C  =  device addr | direct register address ($DR)
    ;input A  =  byte to write
    ;preserves device and register address in BC

i2c_write_indirect:
    push bc             ;preserve the device and register address
    push af             ;preserve the byte to write
    ld b, c             ;prepare device and register address
                        ;lower address bits (0x1F) of B irrelevant
    ld a, c             ;prepare indirect address in A
    and $07             ;ensure upper bits are zero
    ld c, PCA_INDPTR
    out (c), a          ;write the indirect address to the PCA_INDPTR
    ld c, PCA_IND       ;prepare device and indirect register address
                        ;lower address bits (0x1F) of B irrelevant
    pop af              ;recover the byte to write
    out (c), a          ;write the byte to the indirect register
    pop bc
    ret

    ;Do a read from the direct registers
    ;input  C =  device addr | direct register address ($DR)
    ;output A =  byte read

i2c_read_direct:
    push bc             ;preserve the device and register address
    ld b, c             ;prepare device and register address
                        ;lower address bits (0x1F) of B irrelevant
                        ;upper address bits (0xFC) of C irrelevant
    in a, (c)           ;get the data from the register
    pop bc
    ret

    ;Do a write to the direct registers
    ;input C  =  device addr | direct register address ($DR)
    ;input A  =  byte to write

i2c_write_direct:
    push bc             ;preserve the device and register address
    ld b, c             ;prepare device and register address
                        ;lower address bits (0x1F) of B irrelevant
                        ;upper address bits (0xFC) of C irrelevant
    out (c), a
    pop bc
    ret

;------------------------------------------------------------------------------
; Main Program, a simple test.

    .module program
    .org program

begin:
    ld (STACKTOP), sp
    ld sp, STACKTOP

    ld hl, msg_1        ;print a welcome message
    call pstr 


    ld sp, (STACKTOP)
    ret


msg_1:      .db     "I2C Test "
            .db     "Program",13,10,13,10,0

;------------------------------------------------------------------------------
; Extra print routines during testing

    ;print CR/LF
pnewline:
    ld a, CR
    rst 08
    ld a, LF
    rst 08
    ret

    ;print a string pointed to by HL, null terminated
pstr:
    ld a, (hl)          ; Get a byte
    or a                ; Is it null $00 ?
    ret z               ; Then RETurn on terminator
    rst 08              ; Print it
    inc hl              ; Next byte
    jr pstr


    ;print contents of HL as 16 bit number in ASCII HEX
phex16:
    push af
    ld a, h
    call phex
    ld a, l
    call phex
    pop af
    ret

    ;print contents of A as 8 bit number in ASCII HEX
phex:
    push af             ;store the binary value
    rlca                ;shift accumulator left by 4 bits
    rlca
    rlca
    rlca
    and $0F             ;now high nibble is low position
    cp 10
    jr c, phex_b        ;jump if high nibble < 10
    add a, 7            ;otherwise add 7 before adding '0'
phex_b:
    add a, '0'          ;add ASCII 0 to make a character
    rst 08              ;print high nibble
    pop af              ;recover the binary value
phex1:
    and $0F
    cp 10
    jr c, phex_c        ;jump if low nibble < 10
    add a, 7
phex_c:
    add a, '0'
    rst 08              ;print low nibble
    ret


    ;print a hexdump of the data in the 512 byte buffer HL
phexdump:
    push af
    push bc
    push hl
    call pnewline
    ld c, 32            ;print 32 lines
phd1:
    xor a               ;print address, starting at zero
    ld h, a
    call phex16
    ld a, ':'
    rst 08
    ld a, ' '
    rst 08

    ld b, 16            ;print 16 hex bytes per line
    pop hl
    push hl    
phd2:
    ld a, (hl)
    inc hl
    call phex           ;print each byte in hex
    ld    a, ' '
    rst 08
    djnz phd2

    ld    a, ' '
    rst 08
    ld    a, ' '
    rst 08
    ld    a, ' '
    rst 08

    pop hl
    ld b, 16            ;print 16 ascii words per line
phd3:
    ld a, (hl)
    inc hl
    and $7f             ;only 7 bits for ascii
    tst $7F
    jr nz, phd3b
    xor a               ;avoid 127/255 (delete/rubout) char
phd3b:
    cp $20
    jr nc, phd3c
    xor a               ;avoid control characters
phd3c:
    rst 08
    djnz phd3
    
    call pnewline
    push hl
    dec c
    jr nz, phd1

    call pnewline
    pop hl
    pop bc
    pop af
    ret

    .end

