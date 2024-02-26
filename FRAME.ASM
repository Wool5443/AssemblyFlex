.model tiny
.code
.286
org 100h
locals @@

STYLE_SHIFT equ 3
HALF_SCREEN_HEIGHT equ 12
BYTES_ROW equ 160
HALF_BYTES_ROW equ 80
FRAME_BORDER equ 8

Start: jmp Main

include PARSE.ASM

;--------------------------------------------------------------
; pascal
; Entry:    (char* style+10, char color+*, char row+6,
;            char width+4)
; Assumes:  es = 0b800h
; Destroys: ax, bx, cx, dx, si, di
;--------------------------------------------------------------
DrawRow proc
    push bp
    mov  bp, sp

    xor  ah, ah

    mov  ax, [bp + 6] ; al = row
    imul di, ax, BYTES_ROW ; di = BYTES_ROW * row

    mov  cx, [bp + 4] ; cx = width

    mov  al, HALF_BYTES_ROW
    sub  al, cl ; al = BYTES_ROW / 2 - width 
    and  al, 0feh ; if al is odd

    add  di, ax ; di = BYTES_ROW * row + BYTES_ROW / 2 - width

    sub  cx, 8 ; for corner elements and side empty space
    push cx
    mov  cx, 3 ; 3 side elements

    mov  al, ' '
    mov  ah, [bp + 8] ; ah = color
    rep  stosw

    mov  si, [bp + 10]

    movsb
    mov  es:[di], ah ; place first corner
    inc  di

    lodsb ; al = middle char

    pop  cx
    rep stosw

    movsb
    mov  es:[di], ah ; place last corner
    inc  di

    mov  al, ' '
    mov  cx, 3
    rep  stosw

    pop bp
    ret 8
endp

;--------------------------------------------------------------
; pascal
; Entry:    (char* text+10, char color+8, char row+6,
;            char width+4)
; Assumes:  es = 0b800h
; Destroys: ax, bx, cx, dx, si, di
;--------------------------------------------------------------
DrawText proc
    push bp
    mov  bp, sp

    ; center shift = (HALF_BYTE_ROW - length)
    mov  ax, [bp + 10]
    mov  si, ax

    sub  ax, 81h ; start of command line
    mov  bx, 80h
    mov  bl, [bx]
    sub  bl, al ; bl = len of str

    mov  ax, [bp + 6] ; al = row
    imul di, ax, BYTES_ROW ; di = BYTES_ROW * row

    add  di, HALF_BYTES_ROW
    sub  di, bx

    and  di, 0fffeh ; if di is odd

    @@Next:
        movsb
        inc  di
        dec  bl
        test bl, bl
        jne  @@Next
    
    pop bp
    ret 8
endp

;--------------------------------------------------------------
; pascal
; Entry:    (char* style+12, char color+10, char width+8,
;            char height+6, char* text+4)
; Assumes:  es = 0b800h
; Destroys: ax, bx, cx, dx, si, di
; vars:     -2: counter - 4, -4: current row, -6: content row
;--------------------------------------------------------------
DrawBox proc
    push bp
    mov  bp, sp

    mov  ax, [bp + 6]
    sub  ax, 4 ; drawing start and end rows outside of cycle
    push ax ; var counter

    ; calculate first row
    mov  al, HALF_SCREEN_HEIGHT
    mov  ah, [bp + 6] ; ah = height
    shr  ah, 1 ; ah = height / 2
    sub  al, ah ; al = 20 - height / 2 - first row
    mov  ah, 0
    push ax ; var current row

    push offset ZeroStyle ; first empty row
    push [bp + 10]
    push ax
    push [bp + 8]
    call DrawRow

    inc  word ptr [bp - 4] ; current row += 1
    push [bp + 12] ; second top row
    push [bp + 10]
    push [bp - 4]
    push [bp + 8]
    call DrawRow

    add  word ptr [bp + 12], STYLE_SHIFT

    mov  ax, [bp - 4]
    inc  ax
    push ax ; first row of content

    @@Next:
        dec  word ptr [bp - 2]
        inc  word ptr [bp - 4] ; current row += 1

        push [bp + 12] ; second top row
        push [bp + 10]
        push [bp - 4]
        push [bp + 8]
        call DrawRow

        cmp  word ptr [bp - 2], 0
        jne  @@Next

    add  word ptr [bp + 12], STYLE_SHIFT

    inc  word ptr [bp - 4] ; current row += 1
    push [bp + 12] ; last row
    push [bp + 10]
    push [bp - 4]
    push [bp + 8]
    call DrawRow

    inc  word ptr [bp - 4] ; current row += 1
    push offset ZeroStyle ; last white row
    push [bp + 10]
    push [bp - 4]
    push [bp + 8]
    call DrawRow

    push [bp + 4]
    push [bp + 10]
    push 12 ; middle row
    push [bp + 8]
    call DrawText

    add  sp, 6

    pop  bp
    ret 10
endp


Main:
    mov ax, 0b800h
    mov es, ax

    call ParseCommandLine

    push ax
    push dx
    push bx
    push cx
    push si
    call DrawBox

    mov ax, 4c00h
    int 21h

ZeroStyle db 9 dup(' ')
OneStyle  db '/-\', '| |', '\_/'
TwoStyle  db 0c9h, 0cdh, 0bbh, 0bah, ' ', 0bah, 0c8h, 0cdh, 0bch
ThrStyle  db 9 dup(3h)

end Start
