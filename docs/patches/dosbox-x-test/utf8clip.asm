; utf8clip.com - UTF-8 text of the clipboard (docs/UTF8CLIPBOARD.md). Finds the
; provider "DOS-UTF8" "CLIPBRD " through AMIS and turns UTF-8 on (AL=10h
; BX=65001), reads the text of the clipboard with WinOldAp (1704h size, 1705h
; data; format 7), prints the size and the bytes as hex, replaces the text with
; UTF-8 bytes (1703h), turns UTF-8 off (AL=10h BX=0) and prints the size of the
; same text once more (now in the OEM code page). Without the provider it
; prints "NOT FOUND".
        org 100h
        cld
        xor bx, bx
scan:   mov ah, bl
        xor al, al
        int 2Dh
        cmp al, 0FFh
        jne next
        mov es, dx
        mov si, expect
        mov cx, 16
        repe cmpsb
        je found
next:   inc bl
        jnz scan
        mov dx, msgnf
        call puts
        mov ax, 4C01h
        int 21h
found:  mov [mux], bl
        push cs
        pop es
        mov ah, [mux]           ; UTF-8 on
        mov al, 10h
        mov bx, 65001
        int 2Dh
        mov [r_ax], ax
        mov [r_bx], bx
        mov dx, msgset
        call puts
        mov al, [r_ax]
        call hex8
        mov dx, msgprev
        call puts
        mov ax, [r_bx]
        call hex16
        call crlf
        mov ax, 1701h           ; open
        int 2Fh
        call size
        mov dx, msgsize
        call puts
        call printsize
        mov ax, 1705h           ; the text
        mov dx, 7
        mov bx, buf
        int 2Fh
        mov dx, msgtext
        call puts
        mov si, buf
.t:     lodsb
        or al, al
        jz .td
        call hex8
        jmp .t
.td:    call crlf
        mov ax, 1702h           ; empty
        int 2Fh
        mov ax, 1703h           ; set: DX format, ES:BX data, SI:CX size
        mov dx, 7
        mov bx, newtext
        xor si, si
        mov cx, newlen
        int 2Fh
        mov [r_ax], ax
        mov dx, msgsetc
        call puts
        mov ax, [r_ax]
        call hex16
        call crlf
        call size               ; the text that the program has just set, as UTF-8
        mov dx, msgsize2
        call puts
        call printsize
        mov ah, [mux]           ; current mode
        mov al, 11h
        int 2Dh
        mov [r_bx], bx
        mov dx, msgmode
        call puts
        mov ax, [r_bx]
        call hex16
        call crlf
        mov ah, [mux]           ; UTF-8 off
        mov al, 10h
        xor bx, bx
        int 2Dh
        call size               ; the same text in the OEM code page
        mov dx, msgoem
        call puts
        call printsize
        mov ax, 1708h           ; close
        int 2Fh
        mov ax, 4C00h
        int 21h

size:   mov ax, 1704h
        mov dx, 7
        int 2Fh
        mov [r_ax], ax
        mov [r_dx], dx
        ret
printsize:
        mov ax, [r_dx]
        call hex16
        mov ax, [r_ax]
        call hex16
        jmp crlf

puts:   mov ah, 9
        int 21h
        ret
crlf:   mov dx, msgcrlf
        jmp puts
hex16:  push ax
        mov al, ah
        call hex8
        pop ax
hex8:   push ax
        shr al, 4
        call nib
        pop ax
        and al, 0Fh
nib:    add al, '0'
        cmp al, '9'
        jbe .p
        add al, 7
.p:     mov dl, al
        mov ah, 2
        int 21h
        ret

expect  db 'DOS-UTF8CLIPBRD '
; "Привет" CR LF "мир" in UTF-8
newtext db 0D0h, 9Fh, 0D1h, 80h, 0D0h, 0B8h, 0D0h, 0B2h, 0D0h, 0B5h, 0D1h, 82h, 13, 10
        db 0D0h, 0BCh, 0D0h, 0B8h, 0D1h, 80h
newlen  equ $ - newtext
msgset  db 'SET=$'
msgprev db ' PREV=$'
msgsize db 'SIZE=$'
msgtext db 'TEXT=$'
msgsetc db 'SETC=$'
msgsize2 db 'SIZE2=$'
msgmode db 'MODE=$'
msgoem  db 'OEM=$'
msgnf   db 'NOT FOUND', 13, 10, '$'
msgcrlf db 13, 10, '$'
mux     db 0
r_ax    dw 0
r_bx    dw 0
r_dx    dw 0
buf     times 256 db 0
