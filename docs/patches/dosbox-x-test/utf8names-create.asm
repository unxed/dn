        org 100h
        mov ah, 0C0h        ; AMIS mux of NAMES is the 2nd provider here: scan
        xor bl, bl
scan:   mov ah, bl
        xor al, al
        int 2Dh
        cmp al, 0FFh
        jne nx
        mov es, dx
        mov si, expect
        mov cx, 16
        repe cmpsb
        je found
nx:     inc bl
        jnz scan
        mov ax,4C01h
        int 21h
found:  push cs
        pop es
        mov ah, bl
        mov al, 10h
        mov bx, 65001
        int 2Dh
        mov ax, 716Ch
        mov bx, 2
        xor cx, cx
        mov dx, 12h          ; create or truncate
        mov si, name
        int 21h
        jc bad
        mov bx, ax
        mov ah, 3Eh
        int 21h
        mov ax, 7156h        ; rename name -> name2
        mov dx, name
        mov di, name2
        int 21h
        jc bad
        mov ax, 4C00h
        int 21h
bad:    mov ax, 4C02h
        int 21h
expect  db 'DOS-UTF8NAMES   '
name    db 'd', 0D0h, 0B4h, 0E6h, 097h, 0A5h, '.dat', 0
name2   db 0E2h, 082h, 0ACh, '.dat', 0
