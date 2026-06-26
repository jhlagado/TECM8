; MON3-lite compatibility stubs.
;
; These labels preserve the existing MON3 API table while bulky optional
; packages are moved out of fixed ROM.

; Storage is being replaced by TEC-FS services.  These entry points stay present
; so old call numbers fail cleanly instead of linking to removed code.
checkSDCardPresent:
        or      1               ; NZ = no SD card present
        ret

loadFromDisk:
openFile:
readSector:
writeSector:
saveRAM:
loadRAM:
        scf                     ; unsupported
        ret

; GLCD services have moved out of the fixed monitor profile.
initLCD:
clearGBUF:
clearGrLCD:
clearTxtLCD:
setGrMode:
setTxtMode:
drawBox:
drawLine:
drawCircle:
drawPixel:
fillBox:
fillCircle:
plotToLCD:
printString:
printChars:
delayUS:
delayMS:
setBufClear:
setBufNoClear:
clearPixel:
flipPixel:
drawGraphic:
invGraphic:
initTerminal:
sendCharToLCD:
sendStringToLCD:
sendRegToLCD:
sendHLToLCD:
setCursor:
getCursor:
displayCursor:
autoLF:
underline:
plotAlways:
        scf                     ; unsupported
        ret
