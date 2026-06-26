; ----------------------------------------------------------------------------
;
; DS1302 RTC API Routines for MON3 - For use with GPIO RTC Card
;
; Written By Craig Hart, 2024
;
; ----------------------------------------------------------------------------
;
; C register - API Call #
; B register - API Function
;
; Calls return C=1 if failed, C=0 if success
;

RTCAPI:
        ld a,b
        cp DSAPIFnMax           ; Valid API Number?
        jr c,APIOk
APIErr: scf                     ; set C flag = Error
        ret

APIok:  add a,a                 ; 2 byte table
        push hl
        push bc
        ld b,0
        ld c,a
        ld hl,DSAPIFunctions
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        push bc
        pop ix
        pop bc
        pop hl
        jp (ix)

; ----------------------------------------------------------------------------
; Determine if a DS1302 is pesent
;
; If all registers return FFh, no DS1302 exists
; ----------------------------------------------------------------------------
checkDS1302Present:
        push de

        ld de,8E00H         ; clear write protect bit
        call rtc_wr
        ld de,9000H         ; clear trickle charge bits
        call rtc_wr

        ld d,81H
        call rtc_rd
        cp 5AH              ; should come back 00..59h
        jr nc, noDS1302

        ld d,8BH
        call rtc_rd
        cp 08H              ; should come back 01..07
        jr nc, noDS1302

        pop de
        or a                ; clear C flag
        ret

noDS1302:
        pop de
        scf                  ; set C flag
        ret

; ----------------------------------------------------------------------------
; Reset the DS1302 fully to a known date/time condition
; does not clear RTC bytes
; ----------------------------------------------------------------------------
resetDS1302:
        push de

        ld de,8E00H        ; clear write protect bit
        call rtc_wr
        ld de,9000H        ; clear trickle charge bits
        call rtc_wr

        ld de, 8000H       ; seconds 00
        call rtc_wr
        ld de, 8200H       ; minutes 00
        call rtc_wr
        ld de, 8490H       ; hours 01, 12 hour mode
        call rtc_wr

        ld de,8601H        ; date 01
        call rtc_wr
        ld de,8801H        ; month 01
        call rtc_wr
        ld de,8A01H        ; day 01 (Monday)
        call rtc_wr
        ld de,8C00H        ; year 00 (2000)
        call rtc_wr

        pop de
        or a               ; clear Z flag
        ret

; ----------------------------------------------------------------------------
; Returns time
;
; H = hour      ; bit 5 = am/pm flag (in 12 hr mode). 1=PM
; L = minute
; D = second
; ----------------------------------------------------------------------------
getTime:
        ld d,85H                ; hour
        call rtc_rd
        and 3FH                 ; strip off bits
        ld h,a

        ld d,83H                ; min
        call rtc_rd
        ld l,a

        ld d,81H                ; sec
        call rtc_rd
        ld d,a

        or a
        ret

; ----------------------------------------------------------------------------
; Sets time; preserves 12/24 hour mode
;
; H = hour             ; bit 5 = am/pm in 12hr mode
; L = minute
; D = second
; ----------------------------------------------------------------------------
setTime:
        ld e,d
        ld d,80H                ; secs
        call rtc_wr

        ld a,h                  ; mask off junk bits
        and 3FH
        ld h,a

        call get1224Mode        ; get 12/24 flag
        or h
        ld e,a
        ld d,84H                ; hour
        call rtc_wr

        ld e,l
        ld d,82H                ; mins
        call rtc_wr

        or a
        ret

; ----------------------------------------------------------------------------
; Returns date
;
; H = date
; L = month
; DE = year 2000..2099
; ----------------------------------------------------------------------------
getDate:
        push bc
  
        ld d,87H                ; date
        call rtc_rd
        ld h,a

        ld d,89H                ; month
        call rtc_rd
        ld l,a

        ld d,8DH                ; year
        call rtc_rd
        ld e,a
        ld d,20H                ; Add '20'xxh

        pop bc
        or a
        ret

; ----------------------------------------------------------------------------
; sets date
;
; H = date
; L = month
; DE = year (Decimal) 2000..2099
; ----------------------------------------------------------------------------
setDate:
        ld d,8CH                ; year  (just ignore '20'xxh)
        call rtc_wr

        ld d,88H                ; month
        ld e,l
        call rtc_wr
        
        ld d,86H                ; date
        ld e,h
        call rtc_wr

        or a
        ret

; ----------------------------------------------------------------------------
; Returns day in D
; returns HL points to day ASCIIZ String
; ----------------------------------------------------------------------------
getDay:
        ld d,8BH                ; day
        call rtc_rd
        and 07H
        ld d,a

        ld hl,daysList
        dec a
        cp 0
        jr z,foundDay
        ld b,a

dayloop:
        ld a,(HL)
        inc hl
        cp 0
        jr nz,dayLoop
        djnz dayLoop

foundDay:
        or a
        ret

; ----------------------------------------------------------------------------
; sets day from D - 01..07
; ----------------------------------------------------------------------------
setDay:
        ld a,d
        cp 0
        jr nz,validDay
        scf
        ret

validDay:
        push de
        and 07H
        ld e,a
        ld d,8AH                ; day
        call rtc_wr

        pop  de
        or a
        ret

; ----------------------------------------------------------------------------
; Returns 12hr / 24hr mode. A = 00h = 24 hour mode, 80h = 12 hr mode
; ----------------------------------------------------------------------------
get1224Mode:
        push de
        ld d,85H                ; hour
        call rtc_rd
        and 80H                 ; mask bits

        pop de
        or a
        ret

; ----------------------------------------------------------------------------
; Sets 12hr mode
; no prameters
; ----------------------------------------------------------------------------
set12HrMode:
        ld d,85H                ; hour
        call rtc_rd
        bit 7,a                 ; is it already 12 hr mode?
        jr z,pr12
        scf                     ; already 12 hour mode dude!
        ret

pr12:   and 3FH                ; 24 hour to 12 hour - strip bits
        cp 00H
        jr nz,notMidnight
        ld a,92H            ; 12am + 12 hour flag
        jr setHour

notMidnight:
        cp 12H
        jr z,setpm            ; 12pm exactly?
        jr nc,ispm            ; >12 ?
        or 80H                ; <12, so hours same, set 12 hour flag
        jr setHour

ispm:   sub 12H                ; convert to 12 hr time
        daa
setpm:  or 0A0H                ; set 12 hour flag + PM fag
        jr setHour

; ----------------------------------------------------------------------------
; Sets 24hr mode
; no prameters
; ----------------------------------------------------------------------------
set24HrMode:
        ld d,85H                ; hour
        call rtc_rd
        bit 7,a                 ; is it already 24 hr mode?
        jr nz,pr24
        scf                     ; already 24 hour mode dude!
        ret

pr24:   and 3FH                ; strip bits 7 and 6 to set 24h mode
        bit 5,a                ; was it pm?
        
        jr z,fixt            ; am? if so am is same as 24hr

        and 1FH                ; clear PM flag
        cp 12H                ; is it 12pm? no change
        jr z,setHour
        add a,12H            ; adjust by adding 12 hours
        daa                ; in BCD
        jr setHour

fixt:   cp 12H                ; 12am = 00 hours
        jr nz,nofix
        xor a

nofix:  and 1FH                ; clear PM flag

; sethour is a Shared function of above 2 calls
setHour:
        ld e,a                ; set clock
        ld d,84H
        call rtc_wr

        or a
        ret

; ----------------------------------------------------------------------------
; formatTime takes in a time, and outputs it as a well structured string
;
; note -- must supply bit 7 if 12hr!!!
;
; H = hour      ; bit 7 = 12/24hr. bit 5 = am/pm flag (in 12 hr mode). 1=PM
; L = minute
; D = second
;
; IY = pointer to where to write output
; ----------------------------------------------------------------------------
formatTime:
        push de
        push iy
        pop de

        ld a,h                 ; get hours
        bit 7,a            ; 1 = 12 hour
        jr z, is24
        and 1FH

is24:   and 3FH
        call AToString

        ld a,':'        ; add deliminator
        ld (de),a
        inc de

        ld a,l          ; get minutes
        call AToString

        ld a,':'        ; add deliminator
        ld (de),a
        inc de

        pop bc

        ld a,b          ; set seconds
        call AToString

        ld a,h          ; work out if AM or PM, or 24 hour mode
        bit 7,a
        jr z,noampm        ; skip AM/PM if 24 hour mode

        ld a,' '        ; add space
        ld (de),a
        inc de

        ld b,'A'

        ld a,h                  ; is it AM or PM 
        and 20H
        jr z,isam

        ld b,'P'
 
isam:   ld a,b            ; copy 2 bytes AM or PM to buffer
        ld (de),a
        inc de
        ld a,'M'
        ld (de),a
        inc de

noampm: xor a            ; null terminate string
        ld (de),a
        ret

; ----------------------------------------------------------------------------
; formatDate takes in a date, and outputs it as a well structured string
;
; H = date
; L = month
; DE = year
;
; IY = pointer to where to write output
; ----------------------------------------------------------------------------
formatDate:
        push de
        push iy
        pop de
        
        ld a,h
        call AToString
        ld a,'/'
        ld (de),a
        inc de

        ld a,l
        call AToString
        ld a,'/'
        ld (de),a
        inc de

        pop bc                  ; year now in BC
        ld a,b
        call AToString
        ld a,c
        call AToString
  
        ld a,0
        ld (de),a

        ret
        
; ----------------------------------------------------------------------------
; Input:        D = byte to return 0..30
; Output:       A = byte read
; ----------------------------------------------------------------------------
readRTCByte:
        ld a,d
        ld d,0
        cp 31
        ret nc          ;exit if greater then 30
        add a,a         ;Double in to get read index
        add a,0C1H
        ld d,a
        call rtc_rd

        or a
        ret

; ----------------------------------------------------------------------------
; Input:        DE = register and byte to write, D=0..30
; ----------------------------------------------------------------------------
writeRTCByte:
        ld a,d
        cp 31
        ret nc          ;exit if greater then 30
        add a,a         ;Double it to get write index
        add a,0C0H
        ld d,a
        call rtc_wr

        or a
        ret

; ----------------------------------------------------------------------------
; Reads all 31 RTC RAM bytes to userbuffer
; input: HL = location to write to (31 bytes to be written)
; ----------------------------------------------------------------------------
burstRTCRead:
        push bc
        push de

        ld c,RTC_PORT
        ld a,10H        ; raise CS, enable data out
        out (c),a
  
        ld d,0FFH        ; ram burst
        call bytelpW        ; write D to select the register

        ld b,31

bRead:  call bytelpR        ; read value (into D)
        ld (hl),d
        inc hl
        djnz bRead

        xor a            ; drop CS & clear CF
        out (c),a

        pop de
        pop bc
        ret

; ----------------------------------------------------------------------------
; Write cycle. Writes 2 bytes
; D = command/register
; E = data byte
; ----------------------------------------------------------------------------
rtc_wr:
        push af
        push bc
        ld c,RTC_PORT
        ld a,10H        ; raise CS, enable data in
        out (c),a
        call bytelpW        ; write D to select the register
        ld d,e
        call bytelpW        ; write E - the data
        xor a            ; drop CS
        out (c),a
        pop bc
        pop af
        ret

; ----------------------------------------------------------------------------
; Read cycle. Writes command and reads result
; D = command/register needed
; A = result
; ----------------------------------------------------------------------------
rtc_rd:
        push bc
        ld c,RTC_PORT
        ld a,10H        ; raise CS, enable data out
        out (c),a
        call bytelpW        ; write D to select the register
        call bytelpR        ; read value (into D)
        xor a            ; drop CS
        out (c),a
        ld a,d            ; return value in A
        pop bc
        ret

; ----------------------------------------------------------------------------
; write one byte to the DS1302
; byte in D
; ----------------------------------------------------------------------------
bytelpW:
        push bc
        ld b,8
 
blp:    srl d            ; data bit 0 to carry
        ld a,20H
        rra            ; carry to data bit 7
        out (c),a        ; setup bus - drops clock
        or 40H            ; raise CLK
        out (c),a
        djnz blp
        pop bc
        ret

; ----------------------------------------------------------------------------
; Read one byte from the DS1302
; byte read is returned in D
; ----------------------------------------------------------------------------
bytelpR:
        push bc

        ld b,8
        ld d,0

blp2:   ld a,30H
        or 40H          ; raise CLK
        out (c),a
        and 0BFH        ; drop CLK
        out (c),a
        in e,(c)        ; read value
        srl e
        rr d
        djnz blp2
        pop bc
        ret

; ----------------------------------------------------------------------------
; Conversion routine - BCD to true Binary
; input:  A = BCD value
; output: A = binary value
; ----------------------------------------------------------------------------
bcdToBin:
        push bc
        ld c,a
        and 0F0H
        srl a
        ld b,a
        srl a
        srl a
        add a,b
        ld b,a
        ld a,c
        and 0FH
        add a,b
        pop bc
        ret

; ----------------------------------------------------------------------------
; Conversion routine - Binary to BCD
; input:  A = binary value
; output: A = BCD value
; ----------------------------------------------------------------------------
binToBcd:
        push    bc
        ld    b,10
        ld    c,-1
div10:  inc    c
        sub    b
        jr    nc,div10
        add    a,b
        ld    b,a
        ld    a,c
        add    a,a
        add    a,a
        add    a,a
        add    a,a
        or    b
        pop    bc
        ret

; ----------------------------------------------------------------------------
; RTC setup UI moved out of the fixed monitor profile.
; ----------------------------------------------------------------------------
RTCSetup:
        scf
        ret

; Get current time and save in local RAM.
; Returns: H = hour      ; bit 5 = am/pm flag (in 12 hr mode). 1=PM
;          L = minute
;          D = second
getRTCTime:
        call getTime
        ld a,d          ;save seconds
        ld (RTC_SECS),a
        ld a,l          ;save minutes
        ld (RTC_MINS),a

        ; check if 12 or 24 hours
        call get1224Mode    ;A = 00H, 24 hour mode, 80h, 12 hr mode
        or h            ;set bit 7 if 12 hour mode in hours data and save it
        ld h,a
        ld (RTC_HOURS),a
        ret

; Checks the state of the RTC checksum (RAM at 31 slot).  Checksum is the twos 
; compliment of the first 16 bytes of RAM.  It will then compare the result
; with the stored checksum in slot 31.
; Input: none
; Output: A = 00 if match or something else if no match
;         Zero Flag = set if calculated checksum = stored checksum
; Destroy: A
checkRTCchecksum:
        call getRTCChecksum
        ld l,a
        ld d,30
        call readRTCByte    ;get stored checksum
        sub l
        ret                 ;Zero flag set if checksum = stored checksum

; Calculate checksum for MON3 stored values.  First 16 bytes of RAM are reserved
; for MON3.  Calculate the checksum of the first 16 bytes.  Checksum is the
; twos compliment of the sum of the 16 bytes
; Input: none
; Output: A = calculated checksum
getRTCChecksum:
        push hl
        push bc
        ld hl,RTC_RAM
        call burstRTCRead   ;put RAM data in RTC_RAM location
        ld hl,RTC_RAM       ;index HL to start position
        ld b,16             ;B=16 bytes to parse
        xor a               ;A=initial checksum
checksumloop:
        ld c,(hl)           ;get RAM value
        add a,c
        inc hl              ;move to next RAM value
        djnz checksumloop
        neg                 ;get the twos compliment
        pop bc
        pop hl
        ret                 ;Zero flag set if checksum = stored checksum

; ----------------------------------------------------------------------------
; RAM Locations
; ----------------------------------------------------------------------------
RTC_BASE:   .equ    0900H       ;Start of RAM location
RTC_SECS:   .equ    RTC_BASE    ;Seconds (1-byte)
RTC_OSEC:   .equ    RTC_BASE+1  ;Old Seconds (1-byte)
RTC_MINS:   .equ    RTC_BASE+2  ;Minutes (1-byte)
RTC_HOURS:  .equ    RTC_BASE+3  ;Hours (1-byte)
RTC_DAY:    .equ    RTC_BASE+4  ;Day of Week (1-byte)
RTC_MONTH:  .equ    RTC_BASE+5  ;Month (1-byte)
RTC_YEAR:   .equ    RTC_BASE+6  ;Year (2-bytes)
RTC_BUFF:   .equ    RTC_BASE+8  ;LCD Buffer (21-bytes)
RTC_RAM:    .equ    RTC_BASE+29 ;RAM Data (31-byte)
RAM_PTR:    .equ    RTC_BASE+60 ;RAM Pointer (1-byte)

; ----------------------------------------------------------------------------
; constants
; ----------------------------------------------------------------------------
RTC_PORT:   .equ 0FCH
daysList:       .db "Monday",0
                .db "Tuesday",0
                .db "Wednesday",0
                .db "Thursday",0
                .db "Friday",0
                .db "Saturday",0
                .db "Sunday",0

DSAPIFunctions: .dw checkDS1302Present
                .dw resetDS1302
                .dw getTime
                .dw setTime
                .dw getDate
                .dw setDate
                .dw getDay
                .dw setDay
                .dw get1224Mode
                .dw set12HrMode
                .dw set24HrMode
                .dw readRTCByte
                .dw writeRTCByte
                .dw burstRTCRead
                .dw bcdToBin
                .dw binToBcd
                .dw formatTime
                .dw formatDate
                .dw RTCSetup

DSAPIFnMax:     .equ ($-DSAPIFunctions)/2
