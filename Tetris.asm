IDEAL
MODEL small
STACK 100h

DATASEG

initial_vid_memory_seg equ 0A000h
initial_vid_memory_offset equ 0000h
row_length equ 320d
column_height equ 200d


CODESEG

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
		jmp endOfProcaddToAddress
	special:
		add di, row_length;add 320d to the offset
		mov ax, es;increase segment
		inc ax
		mov es, ax
		
	endOfProcaddToAddress:
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
proc find_address
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
		endp find_address

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
	
	;check if the input is valid (X+weight<320, Y+height<200)
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
	call find_address
	
	mov bx, param_height
	loopHeight:	
		mov cx, param_width;init cx for the width loop
		loopWidth:
			mov ax, param_color;save the color in ax
			;mov dx, di;save the offset of the address in dx
			mov [es:di], ax;write the color to the address
			;out [1000h:[dx]], ax;write the color to the address (WONT WORK!)
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

	push 0C8h;X = 200d
	push 96h;Y = 150d
	push 50d;width = 100d 
	push 0Ah;height = 50d
	push 4h;color = 4d
	call drawRect

exit:
	mov ax, 4c00h
	int 21h
END start
