IDEAL
MODEL small
STACK 100h

DATASEG

initial_vid_memory_seg equ 0A000h
initial_vid_memory_offset equ 0000h
row_length equ 320d
column_height equ 200d
square_side equ 10d


shapes_buffer db 4 dup(0);this buffer contains the shapes of the game: 0=square, 1=straight line, 2=L, 3=pyramid, 4=stair
current_shape_index db 0;

CODESEG

;this procedure creates 4 random numbers between 0-4
;and puts them in the shapes_buffer
;0 = square
;1 = straight line
;2 = L
;3 = pyramid
;4 = stair
proc initShapesBuffer
	;init bp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	push bx
	push es
	
	mov bx, 4
	fillBufferLoop:
		dec bx
		;create the random numbers
		mov ax, 0040h
		mov es, ax
		mov ax, [es:006Ch];0040h:006Ch is the address of the clock counter
		and al, 00000111b;create a random number between 0-7
		cmp al, 4h
		ja fillBufferLoop;craete another one if the number too big
		mov [offset shapes_buffer + bx], al;save the number in the buffer
		cmp bx, 0
		ja fillBufferLoop
	
	endOfProcInitShapesBuffer:
		pop es
		pop bx
		pop ax
		pop bp
		ret 
		endp initShapesBuffer
		

;This procedure gets the current address (seg:offset) and 
;the width of the shape and makes it move to the start of 
;the shape in the next line in a way that will work with 
;the protocol of video memory
;PARAMS:
;	es - the segment
;	di - the offset
;	width (byValue)
proc getNextLineAddress
	Pwidth equ [word ptr bp + 4]
	
	;init bp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	
	
	sub di, Pwidth;return to the X point of the shape
	
	;move it to the next line
	mov ax, row_length;mov 320d to add to ax
	add ax, di;	;add the size of a row to the address	
	jc special;check overflow (number_to_add+offset>FFFF). need to increase segment
	
	noraml:
		add di, row_length;add 320d to the offset
		jmp endOfProcGetNextAddress
	special:
		add di, row_length;add 320d to the offset
		mov ax, es;increase segment
		inc ax
		mov es, ax
		
	endOfProcGetNextAddress:
		pop ax
		pop bp
		ret 2
		endp getNextLineAddress
	
	

	
;this procedure gets X and Y coordinants and find the right
;I/O address to put the data in and stores it in es:di
;PARAMS:
;	X (byValue)
;	Y (byValue)
;RETURNS:
;	es - the I/O memory segment of the pixel
;	di - the I/O memory offset of the pixel
proc findAddress
	;initBp
	push bp
	mov bp, sp
	
	;save registers state
	push cx
	push ax
	push dx
	push si
	
	mov ax, [bp + 4]; mov Y to ax
	mov cx, row_length; mov 320 to cx
	
	mul cx; save ax*cx in dx:ax (Y means how many rows to multiply 320 with)
	mov si, dx;mov dx to si (now the address is in si:ax)
	add si, initial_vid_memory_seg;add the initial segment of the video memory address
	add ax, initial_vid_memory_offset;add the initial offset of the video memory address
	jnc addXToAddress
	;overflow
	inc ax;do we really need this inc????
	inc si
	
	addXToAddress:
		add ax, [bp + 6]; add X to the address
		jnc endOfProcFindAddress;the address in ax + the X value is below 0FFFFh
		inc ax;do we really need this inc????
		inc si
	
	endOfProcFindAddress:
		mov di, ax;mov ax to di (now the address is in si:di)
		mov es, si;mov si to es (now the address is in es:di)
		pop si
		pop dx
		pop ax
		pop cx
		pop bp
		ret 4
		endp findAddress

; this procedure gets X,Y coordinants, width, height and color
; as parameters and draws a rectangle in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	width (byValue)
;	height (byValue)
;	color (byValue)
proc drawRect
	param_x equ [word ptr bp + 12]
	param_y equ [word ptr bp + 10]
	param_width equ [word ptr bp + 8]
	param_height equ [word ptr bp + 6]
	param_color equ [word ptr bp + 4]
	
	;initBp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	push dx
	push cx
	push bx
	
	;check if the input is valid (X+width<320, Y+height<200)
	checkInput:		
		;check X+W
		mov ax, param_x
		add ax, param_width
		cmp ax, row_length
		ja illigalSizes
		;check Y+H
		mov ax, param_y
		add ax, param_height
		cmp ax, column_height
		ja illigalSizes
	
	;get the wanted address and save it in es:di
	push param_x
	push param_y
	call findAddress
	
	mov bx, param_height
	loopHeight:	
		mov cx, param_width;init cx for the width loop
		loopWidth:
			mov ax, param_color;save the color in ax
			mov [es:di], ax;write the color to the address
			inc di;draw next pixel
			endOfLoopWidth:
				loop loopWidth
		
		
		push param_width
		call getNextLineAddress;add a row to the address to get down one row 
		
		endOfLoopHeight:
			dec bx
			cmp bx, 0
			jne loopHeight 
	
	endOfProcDrawRect:
		pop bx
		pop cx
		pop dx
		pop ax
		pop bp
		ret	10
	illigalSizes:
		mov ax, 4c01h
		int 21h
	endp drawRect


start:
	mov ax, @data
	mov ds, ax
	
	mov ax, 13h;set mode to graphics
	int 10h
	
	call initShapesBuffer

	push 20d;X
	push 30d;Y
	push 4d;color
	call drawStraightLine
	
	push 70d;X 
	push 30d;Y 
	push 4h;color
	call drawL
	
	push 100d;X 
	push 30d;Y 
	push 4h;color
	call drawBigSquare
	
	push 130d;X 
	push 30d;Y 
	push 4h;color
	call drawStair
	
	push 160d;X 
	push 30d;Y 
	push 6h;color
	call drawPyramid

	
	
	
;this procedure gets X,Y coordinants and color
;and draws a square in the smallest size in the game
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
proc drawBasicSquare
	param_x equ [word ptr bp + 8]
	param_y equ [word ptr bp + 6]
	param_color equ [word ptr bp + 4]	
	
	push bp
	mov bp, sp
	
	push param_x;X
	push param_y;Y
	push square_side;square side
	push square_side;square side
	push param_color;color
	call drawRect
	
	pop bp
	ret 6
	endp drawBasicSquare
	

; this procedure gets X,Y coordinants and color
; as parameters and draws an L shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
proc drawL
	param_x equ [word ptr bp + 8]
	param_y equ [word ptr bp + 6]
	param_color equ [word ptr bp + 4]

	;init bp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	push bx
		
	mov ax,param_x;save current X in ax 
	mov bx,param_y;save current Y in bx
	
	;first square
	push ax;X
	push bx;Y
	push param_color
	call drawBasicSquare
	
	;second square
	push ax;X
	add bx, square_side
	push bx;Y + square_side
	push param_color
	call drawBasicSquare
	
	;third square
	push ax;X
	add bx, square_side;Y+square_side+square_side
	push bx;Y
	push param_color
	call drawBasicSquare
	
	;fourth square
	add ax, square_side
	push ax;X + square_side
	push bx;Y
	push param_color
	call drawBasicSquare
	
	
	endOfProcDrawL:
		pop bp
		pop bx
		pop ax
		ret 6
		endp drawL
		
		
; this procedure gets X,Y coordinants and color
; as parameters and draws a stair-like shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
proc drawStair
	param_x equ [word ptr bp + 8]
	param_y equ [word ptr bp + 6]
	param_color equ [word ptr bp + 4]

	;init bp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	push bx
		
	mov ax,param_x;save current X in ax 
	mov bx,param_y;save current Y in bx
	
	;first square
	push ax;X
	push bx;Y
	push param_color
	call drawBasicSquare
	
	;second square
	add ax, square_side
	push ax;X + square_side
	push bx;Y 
	push param_color
	call drawBasicSquare
	
	;third square
	push ax;X + square_side
	add bx, square_side
	push bx;Y + square_side
	push param_color
	call drawBasicSquare
	
	;fourth square
	add ax, square_side
	push ax;X + square_side + square_side
	push bx;Y + square_side
	push param_color
	call drawBasicSquare
	
	
	endOfProcDrawStair:
		pop bp
		pop bx
		pop ax
		ret 6
		endp drawStair
		
; this procedure gets X,Y coordinants and color
; as parameters and draws a pyramid-like shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
proc drawPyramid
	param_x equ [word ptr bp + 8]
	param_y equ [word ptr bp + 6]
	param_color equ [word ptr bp + 4]

	;init bp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	push bx
		
	mov ax,param_x;save current X in ax 
	mov bx,param_y;save current Y in bx
	
	;first square
	push ax;X
	push bx;Y
	push param_color
	call drawBasicSquare
	
	;second square
	add ax, square_side
	push ax;X + square_side
	push bx;Y 
	push param_color
	call drawBasicSquare
	
	;third square
	push ax;X + square_side
	sub bx, square_side
	push bx;Y - square_side
	push param_color
	call drawBasicSquare
	
	;fourth square
	add ax, square_side
	push ax;X + square_side + square_side
	add bx, square_side
	push bx;Y 
	push param_color
	call drawBasicSquare
	
	
	endOfProcDrawPyramid:
		pop bp
		pop bx
		pop ax
		ret 6
		endp drawPyramid
		
		
; this procedure gets X,Y coordinants and color
; as parameters and draws a big square shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
proc drawBigSquare
	param_x equ [word ptr bp + 8]
	param_y equ [word ptr bp + 6]
	param_color equ [word ptr bp + 4]

	;init bp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	push bx
		
	mov al, square_side;save square_side in ax for multipication
	mov bl, 2
	mul bl
	
	push param_x;X
	push param_y;Y
	push ax;width
	push ax;Side
	push param_color;color
	call drawRect
	
	endOfProcDrawBigSquare:
		pop bx
		pop ax
		pop bp
		ret 6
	endp drawBigSquare
	
; this procedure gets X,Y coordinants and color
; as parameters and draws a big line shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
proc drawStraightLine
	param_x equ [word ptr bp + 8]
	param_y equ [word ptr bp + 6]
	param_color equ [word ptr bp + 4]

	;init bp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	push bx
	
	mov al, square_side;save square_side in ax for multipication
	mov bl, 4
	mul bl
	
	push param_x;X
	push param_y;Y
	push square_side;width
	push ax;height
	push param_color;color
	call drawRect
	
	endOfProcDrawStraightLine:
		pop bx
		pop ax
		pop bp
		ret 6
	endp drawStraightLine
	
	
exit:
	mov ax, 4c00h
	int 21h
END start
