.model tiny
.286
.code
org 100h
locals @@

STYLE_SHIFT equ 3
HALF_SCREEN_HEIGHT equ 12
BYTES_ROW equ 160
HALF_BYTES_ROW equ 80
FRAME_BORDER equ 8
COLOR equ 4fh

Start: jmp SetInt

;--------------------------------------------------------------
; Interruption that changes flag for print reg
;--------------------------------------------------------------
ChangeFlag proc
    push ax
    in   al, 60h
    cmp  al, 47h ; home
    pop  ax
    jne  @@End
    not  byte ptr cs:[offset PRINT_FLAG]
    @@End:
               db 0eah
OldInt9Offset  dw 0
OldInt9Segment dw 0
endp

;--------------------------------------------------------------
; Interruption, that prints all registers every timer tick
; if the variable is set to true. It switches on home.
;--------------------------------------------------------------
IntPrintRegs proc
    cmp  byte ptr cs:[offset PRINT_FLAG], 0
    je   @@End
    pusha ; save all registers

    mov  bp, sp
    add  word ptr [bp + 6], 4 ; sp is decreased by 4 when int
    push [bp + 16]
    push [bp + 18]
    push ss
    push es
    push ds

    mov  ax, 0b800h
    mov  es, ax
    push cs:[offset TwoStyle]
    push COLOR
    push 13
    push 16
    cld
    call DrawBox

    pop  ds es
    add  sp, 6
    popa
    @@End:
               db 0eah
OldInt8Offset  dw 0
OldInt8Segment dw 0
endp

;--------------------------------------------------------------
; pascal
; Entry:    (char* style+10, char color+8, char row+6,
;            char width+4)
; Assumes:  es = 0b800h
; Destroys: ax, bx, cx, dx, si, di
;--------------------------------------------------------------
DrawRow proc
    push bp
    mov  bp, sp

    xor  ah, ah
    mov  ax, cs
    mov  ds, ax

    mov  ax, [bp + 6] ; al = row
    imul di, ax, BYTES_ROW ; di = BYTES_ROW * row

    mov  al, ' '
    mov  ah, [bp + 8] ; ah = color
    stosw

    mov  si, [bp + 10]

    movsb
    mov  es:[di], ah ; place first corner
    inc  di

    lodsb ; al = middle char

    mov  cx, [bp + 4] ; cx = width
    sub  cx, 4
    rep stosw

    movsb
    mov  es:[di], ah ; place last corner
    inc  di

    mov  al, ' '
    stosw

    pop bp
    ret 8
endp

;--------------------------------------------------------------
; pascal
; Entry:    (char* style+10, char color+8, char width+6,
;            char height+4)
; Assumes:  es = 0b800h
; Destroys: ax, bx, cx, dx, si, di
; vars:     -2: shifted style, -4: row cntr, -6: loop cntr
;--------------------------------------------------------------
DrawBox proc
    push bp
    mov  bp, sp

    push offset ZeroStyle
    push [bp + 8]
    push 0
    push [bp + 6]
    call DrawRow

    push offset TwoStyle
    push [bp + 8]
    push 1
    push [bp + 6]
    call DrawRow

    mov  ax, offset TwoStyle
    add  ax, STYLE_SHIFT
    push ax
    push 2
    mov  cx, [bp + 4]
    sub  cx, 3
    push cx

    @@Next:
        push [bp - 2]
        push [bp + 8]
        push [bp - 4]
        push [bp + 6]
        call DrawRow
        dec  word ptr [bp - 6]
        inc  word ptr [bp - 4]
        cmp  word ptr [bp - 6], 0
        jne  @@Next

    mov  ax, [bp - 2]
    add  ax, STYLE_SHIFT

    push ax
    push [bp + 8]
    push [bp - 4]
    push [bp + 6]
    call DrawRow
    inc  word ptr [bp - 4]

    push offset ZeroStyle
    push [bp + 8]
    push [bp - 4]
    push [bp + 6]
    call DrawRow

    ; now i draw registers
    add  sp, 6 ; delete my vars

    mov  ax, [bp + 36]
    mov  dx, "ax"
    mov  bx, 2
    call PrintReg

    mov  ax, [bp + 30]
    mov  dx, "bx"
    mov  bx, 3
    call PrintReg

    mov  ax, [bp + 34]
    mov  dx, "cx"
    mov  bx, 4
    call PrintReg

    mov  ax, [bp + 32]
    mov  dx, "dx"
    mov  bx, 5
    call PrintReg

    mov  ax, [bp + 24]
    mov  dx, "si"
    mov  bx, 6
    call PrintReg

    mov  ax, [bp + 22]
    mov  dx, "di"
    mov  bx, 7
    call PrintReg
    
    mov  ax, [bp + 26]
    mov  dx, "bp"
    mov  bx, 8
    call PrintReg

    mov  ax, [bp + 28]
    mov  dx, "sp"
    mov  bx, 9
    call PrintReg

    mov  ax, [bp + 12]
    mov  dx, "ds"
    mov  bx, 10
    call PrintReg

    mov  ax, [bp + 14]
    mov  dx, "es"
    mov  bx, 11
    call PrintReg

    mov  ax, [bp + 16]
    mov  dx, "ss"
    mov  bx, 12
    call PrintReg

    mov  ax, [bp + 18]
    mov  dx, "cs"
    mov  bx, 13
    call PrintReg

    mov  ax, [bp + 20]
    mov  dx, "ip"
    mov  bx, 14
    call PrintReg

    pop  bp
    ret  8
endp

;--------------------------------------------------------------
; Entry:   ax - reg to print; dh, dl - reg name, bx - row
; Result:
; Destorys: ax, bx, cx, dx
;--------------------------------------------------------------
PrintReg proc
    imul bx, 160d
    mov  byte ptr es:[bx + 4], dh
    mov  byte ptr es:[bx + 6], dl
    call RegToStr
    mov  byte ptr es:[bx + 10], '='
    mov  byte ptr es:[bx + 14], ch
    mov  byte ptr es:[bx + 16], cl
    mov  byte ptr es:[bx + 18], dh
    mov  byte ptr es:[bx + 20], dl
    ret
endp

;--------------------------------------------------------------
; Entry:    ax
; Result:   ch, cl, dh, dl
; Destroys: ax, cx, dx
;--------------------------------------------------------------
RegToStr proc ; ax = 45afh
    push ax
    and  al, 0fh
    cmp  al, 10
    jb   @@Number1
    add  al, 'A' - '0' - 10
    @@Number1:
    add  al, '0'
    mov  dl, al

    pop  ax
    push ax
    and  al, 0f0h
    shr  al, 4
    cmp  al, 10
    jb   @@Number2
    add  al, 'A' - '0' - 10
    @@Number2:
    add  al, '0'
    mov  dh, al

    pop  ax
    push ax
    and  ah, 0fh
    cmp  ah, 10
    jb   @@Number3
    add  ah, 'A' - '0' - 10
    @@Number3:
    add  ah, '0'
    mov  cl, ah

    pop  ax
    and  ah, 0f0h
    shr  ah, 4
    cmp  ah, 10
    jb   @@Number4
    add  ah, 'A' - '0' - 10
    @@Number4:
    add  ah, '0'
    mov  ch, ah

    ret
endp

PRINT_FLAG db 0
ZeroStyle db 9 dup(' ')
; TwoStyle  db 0c9h, 0cdh, 0bbh, 0bah, ' ', 0bah, 0c8h, 0cdh, 0bch
TwoStyle  db 4 dup(03h), ' ', 4 dup(03h)
TO_SAVE:
SetInt:
    mov  ax, 3508h
    int  21h
    mov  OldInt8Offset, bx
    mov  bx, es
    mov  OldInt8Segment, bx

    mov  ax, 2508h
    mov  dx, offset IntPrintRegs
    mov  bx, cs
    mov  ds, bx
    int  21h

    mov  ax, 3509h
    int  21h
    mov  OldInt9Offset, bx
    mov  bx, es
    mov  OldInt9Segment, bx

    mov  ax, 2509h
    mov  dx, offset ChangeFlag
    mov  bx, cs
    mov  ds, bx
    int  21h

    ; mov  ax, 1111h
    ; mov  bx, 2222h
    ; mov  cx, 3333h
    ; mov  dx, 4444h
    ; push 5555h
    ; pop  si
    ; push 6666h
    ; pop  di
    ; push 7777h
    ; pop  bp

    ; push 5288h
    ; call IntPrintRegs

    mov  ax, 3100h
    mov  dx, offset TO_SAVE
    shr  dx, 4
    inc  dx
    int  21h

end Start
