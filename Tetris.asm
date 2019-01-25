IDEAL
MODEL small
STACK 100h

DATASEG
;-------------------------------------------
;-----------------CONSTANTS-----------------
;-------------------------------------------
;screen constants
row_length equ 320d
column_height equ 200d
;video memory constants
initial_vid_memory_seg equ 0A000h
initial_vid_memory_offset equ 0000h
;shapes_buffer constants
shapes_buffer_size equ 4d
;color constants
black equ 0

;game constants
square_side equ 10d;small square side size
X0 equ 150d;the X in which a new shape should be created
Y0 equ 20d;the Y in which a new shape should be created
delta_x equ 20d;the distance to move when movement on X axis is required
delta_y equ 20d;the distance to move when movement on Y axis is required
hovering_time equ 2d;the time between fallings of the shapes
;-------------------------------------------
;-----------------VARIABLES-----------------
;-------------------------------------------
;shapes_buffer data
shapes_buffer db shapes_buffer_size dup(0);this buffer contains the shapes of the game: 0=square, 1=straight line, 2=L, 3=pyramid, 4=stair
next_shape_index db 0;the index of the next shape in the shapes_buffer
;current shape data
current_shape_X dw 0
current_shape_Y dw 0
current_shape_type dw 0
current_shape_config dw 0
current_shape_color dw 0

oldSecs db ?

CODESEG
;-------------------DEPRECATED - USING NEG INSTEAD-------------------
;this procedure gets a number and returns 
;its absolute value over the dx register
;PARMAS:
;	number (byValue) - signed
;RETURNS
;	the absolute value of the number (byValue) - signed - on regiser dx
proc absoluteValue
	param_num equ [bp + 4]
	
	;initBp
	push bp
	mov bp, sp
	
	;check if positive or negative
	mov dx, param_num
	shl dx, 1
	jnc pos
	
	;the number is negative (biggest bit = 1)
	mov dx, param_num
	xor dx, 1111111111111111b;0->1, 1->0
	inc dx; according to the completment to two method
	jmp endOfProcAbsoluteValue	

	;the number is positive (biggest bit = 0)
	pos:
		mov dx, param_num
	
	endOfProcAbsoluteValue:
		pop bp
		ret 
	endp absoluteValue
	

;this procedure gets dx and dy as parameters 
;and moves the current shape to the desired location
;PARAMS:
;	dx (byValue) - signed
;	dy (byValue) - signed
proc move
	param_dx equ [bp + 6]
	param_dy equ [bp + 4]
	
	;initBp
	push bp 
	mov bp, sp
	
	;save registers state
	push ax
	;delete current shape
	mov ax, [current_shape_color];save real color
	mov [current_shape_color], black
	call drawCurrentShape
	mov [current_shape_color], ax;recreate the color 
	
	;check if dX movment is negative or positive
	mov ax, param_dx
	shl ax, 1
	jnc positive
	
	;move left
	negative:
		;make it positive
		mov ax, param_dx
		neg ax
			
		;move the shape
		sub [current_shape_X], ax
		mov ax, param_dy
		add [current_shape_Y], ax
		jmp endOfProcMove
	
	;move right 	
	positive:
		;move the shape
		mov ax, param_dx
		add [current_shape_X], ax
		mov ax, param_dy
		add [current_shape_Y], ax
	
	endOfProcMove:
		call drawCurrentShape
		pop ax
		pop bp
		ret 4
		endp move
		
;this procedure rotates the shape to the right
;which means increases its configuration by 1
;PARAMS:
;	NONE
proc rotateCurrentShapeRight
	;delete current shape
	push [current_shape_color]
	mov [current_shape_color], black
	call drawCurrentShape
	;draw the shpae with new configuration
	pop [current_shape_color]
	inc [current_shape_config]
	cmp [current_shape_config], 4
	jbe endOfProcRotateRight
	mov [current_shape_config], 0 
	
	endOfProcRotateRight:
		call drawCurrentShape
		ret	
		endp rotateCurrentShapeRight
	
;this procedure rotates the shape to the left
;which means decreases its configuration by 1
;PARAMS:
;	NONE
proc rotateCurrentShapeLeft
	;delete current shape
	push [current_shape_color]
	mov [current_shape_color], black
	call drawCurrentShape
	;draw the shpae with new configuration
	pop [current_shape_color]
	dec [current_shape_config]
	cmp [current_shape_config], 1
	jae endOfProcRotateRight
	mov [current_shape_config], 4

	endOfProcRotateLeft:
		call drawCurrentShape
		ret	
		endp rotateCurrentShapeLeft
	
	
;this procedure draws the current shape according 
;to the data about them stored in DATASEG
;PARAMS
;	NONE
proc drawCurrentShape
		push [current_shape_X]
		push [current_shape_Y]
		push [current_shape_color]
		push [current_shape_config]
		;check type
		cmp [current_shape_type], 0;0=square
		je square
		cmp [current_shape_type], 1;1=straight line
		je straight
		cmp [current_shape_type], 2;2=L
		je L
		cmp [current_shape_type], 3;3=pyramid 
		je pyramid
		jmp stair;4=stair
	
		square:
			call drawBigSquare
			jmp endOfProcDrawCurrenShape
		straight:
			call drawStraightLine
			jmp endOfProcDrawCurrenShape
		L:
			call drawL
			jmp endOfProcDrawCurrenShape
		pyramid:
			call drawPyramid
			jmp endOfProcDrawCurrenShape
		stair:
			call drawStair
	
	endOfProcDrawCurrenShape:
		ret
		endp drawCurrentShape

;this procedure creates 4 random numbers between 0-4
;and puts them in the shapes_buffer
;0 = square
;1 = straight line
;2 = L
;3 = pyramid
;4 = stair
;PARAMS:
;	NONE
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
		;create the random numbers
		mov ax, 0040h
		mov es, ax
		mov ax, [es:006Ch];0040h:006Ch is the address of the clock counter
		xor al, [byte cs:2212h+bx]
		and al, 00000111b;create a random number between 0-7
		cmp al, 4h
		ja fillBufferLoop;create another one if the number too big
		mov [offset shapes_buffer + bx - 1], al;save the number in the buffer
		dec bx
		cmp bx, 0
		ja fillBufferLoop
	
	endOfProcInitShapesBuffer:
		pop es
		pop bx
		pop ax
		pop bp
		ret 
		endp initShapesBuffer
		
;this procedure updates the current_shape's data according to the item in the shapes_buffer located it the next_shape_index index.
;it also creates another random number to put in the shapes_buffer, and increases the next_shape_index variable by 1.
;CURRENT_SHAPE'S DATA:
;	current_shape_X -> X0
;	current_shape_Y -> Y0
;	current_shape_color -> rand(1-8)
;	current_shape_config -> 0
;	current_shape_type -> shapes_buffer[next_shape_index]
;PARAMS:
;	NONE
proc getNextShape
	;save registers state
	push es
	push ax
	push bx
	
	;update location
	mov [current_shape_X], X0
	mov [current_shape_Y], Y0
	
	;create a random color between 1-8
	mov ax, 0040h
	mov es, ax
	mov ax, [es:006Ch];0040h:006Ch is the address of the clock counter
	and al, 00000111b;create a random number between 0-7
	mov ah,0h
	inc ax;move it from 0-7 to 1-8
	mov [current_shape_color], ax
	
	;initialize the current_shape's configuration
	mov [current_shape_config], 0
	
	;set the shape's type
	mov bl, [next_shape_index];save the index of the next shape in bl
	xor bh, bh
	mov ax, [offset shapes_buffer + bx];save the type of the next shape in ax
	xor ah, ah
	mov [current_shape_type],ax;update the current_shape_type variable
	
	;create a random number for the next shape
	createRandomShapeToBuffer:
		;create the random number
		mov ax, 0040h
		mov es, ax
		mov ax, [es:006Ch];0040h:006Ch is the address of the clock counter
		mov bl, [next_shape_index]
		xor al, [byte offset shapes_buffer + bx]
		and al, 00000111b;create a random number between 0-7
		cmp al, 4h
		ja createRandomShapeToBuffer;create another one if the number too big
		mov bl, [next_shape_index]
		mov bh, 0
		mov [offset shapes_buffer + bx], al;save the number in the buffer
		
	;increase next_shape_index
	inc [next_shape_index]
	cmp [next_shape_index], shapes_buffer_size
	jb endOfProcGetNextShape;check if the index is legal
	mov [next_shape_index], 0;set index to 0 if bigger then the size of the buffer
	
	endOfProcGetNextShape:
		pop bx
		pop ax
		pop es
		ret
		endp getNextShape
		
		
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
;              ._____
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
		

		
		
		
;this procedure checks the keyboard port for data, and
;chenges the game's state accordingly
;PARAMS
;	NONE
proc listenToKeyboard
	;save registers state
	push dx
	push ax
	;check for data
	mov ah,1h
	int 16h
	jz endOfProcListenToKeyboard;no data
	
	;read the data: al=ASCII, ah=SCAN CODE
	mov ah, 0h
	int 16h
	;up
	cmp ah, 48h
	je upButton
	;down
	cmp ah, 50h
	je downButton
	;left
	cmp ah, 4bh
	je leftButton
	;right
	cmp ah, 4dh
	je rightButton
		
	jmp endOfProcListenToKeyboard
		
	;rotate shape right
	upButton:
		call rotateCurrentShapeRight
		jmp endOfProcListenToKeyboard
	;rotate shape left
	downButton:
		call rotateCurrentShapeLeft
		jmp endOfProcListenToKeyboard
	;mov shape left
	leftButton:
		xor ax, ax
		sub ax, delta_x
		push ax;dX = -delta_x
		push 0;dY = 0
		call move
		jmp endOfProcListenToKeyboard
	;move shape right
	rightButton:
		push delta_x;dX=delta_x
		push 0;dY=0
		call move
		
	endOfProcListenToKeyboard:
		pop dx
		pop ax
		ret
		endp listenToKeyboard
		

start:
	mov ax, @data
	mov ds, ax
	
	mov ax, 13h;set mode to graphics
	int 10h
	
	call initShapesBuffer	
	gameLoop:
		mov bx, 3;save the number of fallings in bx
		call getNextShape
		;fall down for 5 sec
		fallingLoop:
			call drawCurrentShape
			push 0d;dx
			push 40d;dy
			call move
		
				;wait for first change in counter 
				initTimer:
					;wait for first change in timer
					mov ax, 0040h
					mov es, ax
					mov ax, [es:006Ch]
					;keep looping here until the counter's value has been changed
					firstTick:
						cmp ax, [es:006Ch]
						je FirstTick;same counter value
				
				
				mov ah, 2ch
				int 21h ;ch- hour, cl- minutes, dh- seconds, dl- hundreths secs
				mov [oldSecs], dh 
				;hover for 2 sec while listenig to the keyboard interrupts 
				hoveringLoop:
					call listenToKeyboard
					mov ah, 2ch
					int 21h;ch- hour, cl- minutes, dh- seconds, dl- hundreths secs
					cmp [oldSecs], dh
					ja differentMinute;oldSecs > newSecs
					
					;newSecs - oldSecs < 2
					sub dh, [oldSecs]
					cmp dh, hovering_time
					jb hoveringLoop
					jmp stopHovering
		
					;60 - oldSecs + newSecs < 2
					differentMinute:
					mov al, 60d
					sub al, [oldSecs]
					add al, dh
					cmp al, hovering_time
					jb hoveringLoop
					
				stopHovering:
					dec bx			
					cmp bx, 0
					je gameLoop
					jne fallingLoop

exit:
	mov ax, 4c00h
	int 21h
END start

