;==================================================================================
;
; DEFINES SECTION
;

USRSTART        .EQU     $FF00 ; start of hexloadr asm code

;WRKSPC          .EQU     $8045 ; set BASIC Work space WRKSPC $8045, RC2014, SBC Searle
;WRKSPC          .EQU     $8120 ; set BASIC Work space WRKSPC $8120, RC2014, ACIA feilipu
WRKSPC          .EQU     $8000 ; set BASIC Work space WRKSPC $8000, YAZ180

                               ; "USR (x)" jump
USR             .EQU     WRKSPC+$03

CR              .EQU     0DH
LF              .EQU     0AH


;==================================================================================
;
; CODE SECTION
;

            .ORG USRSTART   ; USR(*) jump location

START:      
            ld hl, initString
            call PRINT

WAIT_COLON:
            RST 10H         ; Rx byte
            cp ':'          ; wait for ':'
            jr nz, WAIT_COLON
            ld ix, 0        ; reset ix to compute checksum
            call READ_BYTE  ; read byte count
            ld b, h         ; store it in bc
            ld c, l         ;
            call READ_BYTE  ; read upper byte of address
            ld d, l         ; store in d
            call READ_BYTE  ; read lower byte of address
            ld e, l         ; store in e
            push de         ; save the HEX starting address until exit
            call READ_BYTE  ; read record type
            ld a, l         ; store in a
            cp 02           ; check if record type is 02 (ESA)
            jr z, ESA_LOAD
            cp 01           ; check if record type is 01 (end of file)
            jr z, END_LOAD
            cp 00           ; check if record type is 00 (data)
            jr nz, INVAL_TYPE ; if not, error

READ_DATA:
            call READ_BYTE
            ld a, l
            ld (de), a
            inc de
            dec bc
            ld a, 0         ; check if bc==0
            or b
            or c
            cp 0
            jr nz, READ_DATA ; if not, loop to get more data

            call READ_BYTE  ; read checksum
            ld a, ixl       ; lower byte of ix should be 0
            cp 0
            jr nz, BAD_CHK

            ld a, '*'
            RST 08H         ; Print it
            jr WAIT_COLON

END_LOAD:
            ld hl, LoadOKStr
            call PRINT
            
            pop de          ; recover the HEX starting address
            ld hl, USR+1    ; get the USR(x) jump location
            ld (hl), e      ; load the low byte of the jump location
            inc hl
            ld (hl), d      ; load the high byte of the jump location
                            ; jump back into Basic,
            ret             ; ready to run our loaded program from Basic

ESA_LOAD:
            ld hl, esaLoadStr
            call PRINT
            jr HANG

INVAL_TYPE:
            ld hl, invalidTypeStr
            call PRINT
            jr HANG

BAD_CHK:
            ld hl, badCheckSumStr
            call PRINT
            jr HANG

HANG:
            nop
            jr HANG

PRINT:
            LD A,(HL)       ; Get character
            OR A            ; Is it $00 ?
            RET Z           ; Then Return on terminator
            RST 08H         ; Print it
            INC HL          ; Next Character
            JR PRINT        ; Continue until $00

READ_BYTE:
            push af
            push de
            RST 10H         ; Rx byte
            sub '0'
            cp 10
            jr c, RD_NBL_2  ; if a<10 read the second nibble
            sub 7           ; else subtract 'A'-'0' (17) and add 10
RD_NBL_2:   
            ld d, a         ; temporary store the first nibble in d
            RST 10H         ; Rx byte
            sub '0'
            cp 10
            jr c, READ_END  ; if a<10 finalize
            sub 7           ; else subtract 'A' (17) and add 10
READ_END:   
            ld e, a         ; temporary store the second nibble in e
            sla d           ; shift register d left by 4 bits
            sla d
            sla d
            sla d
            or d            ; assemble two nibbles into one byte
            pop de
            ld h, 0
            ld l, a

            push bc         ; add the byte read to ix (for checksum)
            ld b, 0
            ld c, l
            add ix, bc
            pop bc
            
            pop af            
            ret             ; return the byte read in l, with h set to 0


initString:        .BYTE CR,LF,"HexLoadr by "
                   .BYTE "Filippo & feilipu"
                   .BYTE CR,LF,0
esaLoadStr         .BYTE "ESA Unsupported",CR,LF,0
invalidTypeStr:    .BYTE "INV TYP",CR,LF,0
badCheckSumStr:    .BYTE "BAD CHK",CR,LF,0
LoadOKStr:         .BYTE "OK",CR,LF,0

            
            .END
