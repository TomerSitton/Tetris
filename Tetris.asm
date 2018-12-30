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

;-------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------THE DIFFERENT DRAWINGS OF THE SQUARE---------------------------------------------
;-------------------------------------------------------------------------------------------------------------------------------------

; this procedure gets X,Y coordinants, configuration number and color
; as parameters and draws a big square shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
;	config_number (byValue)
;
;              1,2,3,4
;               .____
;	           |    |
;		       |____|
;
proc drawBigSquare
	param_x equ [word ptr bp + 10]
	param_y equ [word ptr bp + 8]
	param_color equ [word ptr bp + 6]
	param_config_number equ [word ptr bp + 4]
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
		ret 8
	endp drawBigSquare

;-------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------THE DIFFERENT DRAWINGS OF THE L--------------------------------------------------
;-------------------------------------------------------------------------------------------------------------------------------------

; this procedure gets X,Y coordinants, num of configuration and color
; as parameters and draws the L shape in the correct position
; and configuration 
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
;	config_number (byValue)
;
;  1			2				3				4
;.__		._______	    .______            .___
;|  |		|	____|	    |__|  |        ____|  |  
;|  |__     |__|               |  |       |_______| 
;|____|                        |__|
proc drawL
	param_x equ [word ptr bp + 10]
	param_y equ [word ptr bp + 8]
	param_color equ [word ptr bp + 6]
	param_config_number equ [word ptr bp + 4]

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
	
	cmp param_config_number, 1
	je L1
	cmp param_config_number, 2
	je L2
	cmp param_config_number, 3
	je L3
	jmp L4
	
	L1:
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
		jmp endOfProcDrawL
		
	L2:
		;second square
		push ax;X
		add bx, square_side
		push bx;Y + square_side
		push param_color
		call drawBasicSquare
	
		;third square
		add ax, square_side
		push ax;X + square_side
		sub bx, square_side;Y
		push bx;Y
		push param_color
		call drawBasicSquare
	
		;fourth square
		add ax, square_side
		push ax;X + square_side + square_side
		push bx;Y
		push param_color
		call drawBasicSquare
		jmp endOfProcDrawL
	L3:
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
		push ax;X 
		add bx, square_side
		push bx;Y + square_side + square_side
		push param_color
		call drawBasicSquare
		jmp endOfProcDrawL
	L4:
		;second square
		sub ax, square_side
		sub ax, square_side		
		push ax;X -square_side - square_side
		add bx, square_side
		push bx;Y + square_side
		push param_color
		call drawBasicSquare
	
		;third square
		add ax, square_side
		push ax;X - square_side
		push bx;Y + square_side
		push param_color
		call drawBasicSquare
	
		;fourth square
		add ax, square_side
		push ax;X  
		push bx;Y + square_side
		push param_color
		call drawBasicSquare
	
	endOfProcDrawL:
		pop bx
		pop ax
		pop bp
		ret 8
		endp drawL


;-------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------THE DIFFERENT DRAWINGS OF THE STRAIGHT LINE -------------------------------------
;-------------------------------------------------------------------------------------------------------------------------------------

; this procedure gets X,Y coordinants and color
; as parameters and draws the different configurations of 
;a big line shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
;	config_number (byValue)
;
;	 1,3			2,4 
;    .__		 .________
;    |  |		 |________|
;    |  |          
;    |  |
;    |__|

proc drawStraightLine
	param_x equ [word ptr bp + 10]
	param_y equ [word ptr bp + 8]
	param_color equ [word ptr bp + 6]
	param_config_number equ [word ptr bp + 4]
	;init bp
	push bp
	mov bp, sp
	
	;save registers state
	push ax
	push bx
	
	mov al, square_side;save square_side in ax for multipication
	mov bl, 4
	mul bl
	
	
	cmp param_config_number, 1
	je verticalLine
	cmp param_config_number, 3
	je  verticalLine
	
	jmp horizontalLine
	
	verticalLine:
		push param_x;X
		push param_y;Y
		push ax;width
		push square_side;height
		push param_color;color
		call drawRect
		jmp endOfProcDrawStraightLine
		
	horizontalLine:
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
		ret 8
	endp drawStraightLine

;-------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------THE DIFFERENT DRAWINGS OF THE STAIR----------------------------------------------
;-------------------------------------------------------------------------------------------------------------------------------------

; this procedure gets X,Y coordinants, configuration number and color
; as parameters and draws a stair-like shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
;	config_number (byValue)
;
;       1,3					2,4
;								___
; 	.______                .___|  |
;   |___   |___            |   ___|
;	   |______|            |__|     
;
proc drawStair
	param_x equ [word ptr bp + 10]
	param_y equ [word ptr bp + 8]
	param_color equ [word ptr bp + 6]
	param_config_number equ [word ptr bp + 4]

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
	
	cmp param_config_number, 1
	je stair1
	cmp param_config_number, 3
	je stair1
	
	jmp stair2
	
	stair1:
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
		jmp endOfProcDrawStair
	
	stair2:
		;second square
		push ax;X 
		sub bx, square_side
		push bx;Y - square_side
		push param_color
		call drawBasicSquare
	
		;third square
		add ax, square_side
		push ax;X + square_side
		add bx, square_side
		push bx;Y
		push param_color
		call drawBasicSquare
	
		;fourth square
		push ax;X + square_side
		add bx, square_side
		push bx;Y + square_side + square_side
		push param_color
		call drawBasicSquare
		jmp endOfProcDrawStair
	
	endOfProcDrawStair:
		pop bx
		pop ax
		pop bp
		ret 8
		endp drawStair
		

;-------------------------------------------------------------------------------------------------------------------------------------
;----------------------------------------------------THE DIFFERENT DRAWINGS OF THE PYRAMID--------------------------------------------
;-------------------------------------------------------------------------------------------------------------------------------------

; this procedure gets X,Y coordinants, configuration number and color
; as parameters and draws a pyramid-like shape in the correct position
;PARAMS:
;	X (byValue)
;	Y (byValue)
;	color (byValue)
;	config_number (byValue)
;
;		1		    	2				3				4
;		___            __        	._________          ___
;  .___|  |___       .|  |__        |___   ___|     .__|  |
;  |_________|        |   __|          |__|         |__   |
;					  |__|	                          |__|
;
proc drawPyramid
	param_x equ [word ptr bp + 10]
	param_y equ [word ptr bp + 8]
	param_color equ [word ptr bp + 6]
	param_config_number equ [word ptr bp + 4]
	
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
	
	cmp param_config_number, 1
	je pyramid1
	cmp param_config_number, 2
	je pyramid2
	cmp param_config_number, 3
	je pyramid3
	
	jmp pyramid4
	
	
	pyramid1:
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
		jmp endOfProcDrawPyramid
	
	pyramid2:
		;second square
		add ax, square_side
		push ax;X + square_side
		push bx;Y 
		push param_color
		call drawBasicSquare
	
		;third square
		sub ax, square_side
		push ax;X
		add bx, square_side
		push bx;Y + square_side
		push param_color
		call drawBasicSquare
	
		;fourth square
		push ax;X
		sub bx, square_side
		sub bx, square_side
		push bx;Y - square_side - square_side
		push param_color
		call drawBasicSquare
		jmp endOfProcDrawPyramid
	
	pyramid3:
		;second square
		add ax, square_side
		push ax;X + square_side
		push bx;Y 
		push param_color
		call drawBasicSquare
	
		;third square
		add ax, square_side
		push ax;X + square_side + square_side
		push bx;Y
		push param_color
		call drawBasicSquare
	
		;fourth square
		sub ax, square_side
		push ax;X + square_side
		add bx, square_side
		push bx;Y + square_side
		push param_color
		call drawBasicSquare
		jmp endOfProcDrawPyramid
	
	pyramid4:
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
		push ax;X + square_side
		sub bx, square_side
		sub bx, square_side
		push bx;Y - square_side
		push param_color
		call drawBasicSquare
		jmp endOfProcDrawPyramid
	
	
	endOfProcDrawPyramid:
		pop bx
		pop ax
		pop bp
		ret 8
		endp drawPyramid
		











		
start:
	mov ax, @data
	mov ds, ax
	
	mov ax, 13h;set mode to graphics
	int 10h
	
	mov ax, 30d
	mov bx, 10d
	mov cx, 4
	mov dx, 4d
	squareLoop:
		push ax;X
		push bx;Y
		push dx;color
		push cx;config_number
		call drawBigSquare
		
		add ax, 40d
		loop squareLoop
	
	mov ax, 30d
	add bx, 40d
	mov cx, 4
	inc dx
	LLoop:
		push ax;X
		push bx;Y
		push dx;color
		push cx;config_number
		call drawL
		
		add ax, 40d
		loop LLoop
		
		
	mov ax, 30d
	add bx, 40d
	mov cx, 4
	inc dx
	LineLoop:
		push ax;X
		push bx;Y
		push dx;color
		push cx;config_number
		call drawStraightLine
		
		add ax, 40d
		loop LineLoop
		
	mov ax, 30d
	add bx, 40d
	mov cx, 4
	inc dx
	StairLoop:
		push ax;X
		push bx;Y
		push dx;color
		push cx;config_number
		call drawStair
		
		add ax, 40d
		loop StairLoop
		
	mov ax, 30d
	add bx, 40d
	mov cx, 4
	inc dx
	PyramidLoop:
		push ax;X
		push bx;Y
		push dx;color
		push cx;config_number
		call drawPyramid
		
		add ax, 40d
		loop PyramidLoop
		
		
		
exit:
	mov ax, 4c00h
	int 21h
END start

