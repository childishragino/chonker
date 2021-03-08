; ***********************************

; First, some assembler directives that tell the assembler:
; - assume a small code space
; - use a 100h size stack (a type of temporary storage)
; - output opcodes for the 386 processor
.MODEL small
.STACK 100h
.386

; Next, begin a data section
.data
	msg DB "CHONKER TERMINATED", 0	; first msg
	nSize DW ($ - msg)-1
	
    xpos DB 20h            ; chonker x-position
	ypos DB 8h			   ; not used in this code. Maybe later.

	seed dw 11             ; Default initial seed of 11   

; Next begins the code portion of the program.
; First, a few useful procedures are defined.
.code

; This procedure creates a 0.1 second delay.

delay proc
	MOV CX, 01h		; 0186A0h = 100000d = .1s delay
	MOV DX, 86A0h
	MOV AH, 86h
	INT 15h	; 0.1 seconds delay	
	RET
delay ENDP

; This procedure places the cursor where we specify.
set_cursor proc
      mov  ah, 2h                 
      mov  bh, 0h                  
      int  10h                   
      RET
set_cursor endp

; ####################################################################################
; The random number code subroutines were taken from
; https://stackoverflow.com/questions/47607104/random-number-in-assembly

; This first routine is used to
; return number between 1 and 10
;  This routine is not used in the chonker game.
; I left it in the code for later use (maybe).  
; Inputs:   AX = value to convert
; Return:   (AX) value between 1 and 10

rand2num1to10 proc
    push dx
    push bx
    xor dx,dx           ; Compute randval(DX) mod 10 to get num
    mov bx,10           ;     between 0 and 9
    div bx
    inc dx              ; DX = modulo from division
                        ;     Add 1 to give us # between 1 and 10 (not 0 to 9)
    mov ax,dx
    pop bx
    pop dx
    ret
rand2num1to10 endp

; Set LCG PRNG seed to system timer ticks
;
; Inputs:   AX = seed
; Modifies: AX 
; Return:   nothing 

srandsystime proc
    push cx
    push dx
    xor ax, ax          ; Int 1Ah/AH=0 to get system timer in CX:DX 
    int 1ah
    mov [seed], dx      ; seed = 16-bit value from DX
    pop dx
    pop cx
    ret
srandsystime endp

; Updates seed for next iteration
;     seed = (multiplier * seed + increment) mod 65536
;     multiplier = 25173, increment = 13849
;
; Inputs: none
; Return: (AX) random value

rand proc
    push dx
    mov ax, 25173       ; LCG Multiplier
    mul word ptr [seed] ; DX:AX = LCG multiplier * seed
    add ax, 13849       ; Add LCG increment value
    mov [seed], ax      ; Update seed
    ; AX = (multiplier * seed + increment) mod 65536
    pop dx
    ret
rand endp
; #################################################################################### 

; This is the main procedure. The assembler knows to make this the entry point
_main PROC

; First, set various registers 
; It's important to set the segment registers.

	MOV DX, @data
	MOV DS, DX

; Next set-up the random number generator	
    call srandsystime   ; Seed PRNG with system time, call once only 

; This is the start of the loop that will run continuously
OuterLoop:	

; draw some rocks
	mov CX, 10         ; CX holds the number of rocks to draw each loop.

drawRocks:
	push CX
    call rand           ; Get a random number in AX
 ;   call rand2num1to10  ; Convert AX to num between 1 and 10 (not used for now).
; I let the set_cursor call deal with the out of range cursor positions
; instead of normalizing the random position.

; draw a rock at a random location on the bottom of the screen
	mov  dl, AL      ; AL is the low byte of AX which contains the random number  
	mov  dh, 18h     ; 18h = 24 decimal which is the bottom row of the screen        
	call set_cursor  ; place the cursor at the random position on the bottom row
	mov AL, 'R'      ; prepare to print an "R"
	mov BH, 0		 ; page 0
	mov BL, 3		 ; color, 3=cyan
	mov CX,1         ; number of characters to print
	mov AH,09h		 ; we want the 09H (print with attribute software int)
	INT 10H			 ; do the software interrupt

; draw the next rock until they are all drawn.
	pop CX			 ; get the counter back from the stack
	LOOP drawRocks	 ; CX=CX-1, if CX>0 then loop back to drawRocks

; scroll the screen
    mov CH,0h		 ; set the scrolling window to the upper-left corner
    mov CL,0h
    mov DH,18h		 	
    mov DL,4Fh		 ; down to the lower right corner.
    mov AL,1h		 ; set the number of lines to scroll to one
    mov AH,06H		 ; this is the int type (scroll)
    INT 10h			 ; call the software interrupt

; see if a rock hit the chonker
	mov  dl, xpos    ; set the cursor position x-coordinate to the xpos of the chonker
	mov  dh, 11h     ; in this version the chonker is always at ypos 11h        
	call set_cursor  ; move the cursor to the chonker's position
	mov BH,0         ; choose page zero
	mov AH,08h       ; we do a 08h call which reads the character at the cursor position
	int 10h			 ; do the software interrupt
	cmp AL,'R'       ; AL contains the ascii code for the character at the chonker location.
	je terminate     ; if there is an "R" at the chonker location, the chonker is terminated
	
; if chonker is safe and position conditions are adequate, print chonker  
	cmp xpos, 0H 		; if chonker is at left edge of screen (0h) 
	je draw_tunnel		; then dont print chonker as he/she has not moved & skip to printing just the tunnel
	cmp xpos, 4FH		; if chonker is at right edge of screen (4fh)
	je draw_tunnel		; then dont print chonker as he/she has not moved & skip to printing just the tunnel
	JMP draw_chonker	; if chonker is not at edges, print the chonker

; if chonker is at wall already then dont print the chonker #, print the tunnel X
draw_tunnel:
	mov  dl, xpos    	; if the chonker didn't move we'll draw an "X" for the tunnel behind him
	mov  dh, 10h     	; draw the tunnel at chonker ypos 11h-1 = 10h row position so the chonker cursor is not overridden         
	call set_cursor  	; place the cursor
	mov AL, 'X'      	; we'll print an "X"
	mov BH, 0		 	; page
	mov BL, 7		 	; color=white
	mov CX,1		 	; 1 copy of "X"
	mov AH,09h		 	; print char with attribute call
	INT 10H			 	; video INT
	JMP draw_chonker 	; draw the chonker cursor now

; if chonker is safe & not on wall edges, draw the chonker
draw_chonker:
	mov  dl, xpos    	; set the cursor position x-coordinate to the xpos of the chonker
	mov  dh, 11h     	; in this version the chonker is always at ypos 11h           
	call set_cursor  	; move the cursor to the chonker's position
	mov AL, '#'		 	; we'll print "#" for the chonker character
	mov BH, 0		 	; use page 0
	mov BL, 7		 	; use white as the color
	mov CX,1		 	; just one chonker
	mov AH,09h		 	; AH=09h will print a character
	INT 10H			 	; do the software interrupt
	JMP continue		; continue with OuterLoop execution

; after dealing with the chonker cursor and adequate wall conditions, continue with code
continue:	

; We wait 0.1 second.	
	CALL delay		 ; delay 0.1 s

; If the "q" is pressed, end the program otherwise loop through the code again.

;CHECK IF KEY WAS PRESSED.
	mov ah, 0bh  ; int type 0bh will see if a key was pressed
  	int 21h      ; RETURNS AL=0 : NO KEY PRESSED, AL!=0 : KEY PRESSED.
  	cmp al, 0
  	je  noKey

;PROCESS KEY.        
  	mov ah, 0	 	; AH=0 will call 
  	int 16h      	; GET THE KEY.
	cmp AL, 'q'     ; terminate if 'q' key has pressed     
	je terminate
	cmp AL, 'a'  	; key pressed was "a"?
	je checkleft    ; check x position (if at left edge) and act accordingly
	cmp AL, 's'  	; key pressed was "s"?
	je checkright   ; check x position (if at right edge) and act accordingly

noKey:
	mov  dl, xpos    ; if the chonker didn't move we'll draw an "X" for the tunnel behind him
	mov  dh, 11h     ; row position        
	call set_cursor  ; place the cursor
	mov AL, 'X'      ; we'll print an "X"
	mov BH, 0		 ; page
	mov BL, 7		 ; color=white
	mov CX,1		 ; 1 copy of "X"
	mov AH,09h		 ; print char with attribute call
	INT 10H			 ; video INT
	
	JMP OuterLoop	 ; continue the game

; is chonker at the LEFT edge of the screen
checkleft:
	cmp xpos, 0H	 ; see if chonker x coordinate equals that of left screen limit
	jne moveleft	 ; if not equal to 0H, move left
	JMP OuterLoop    ; else continue the game without moving left or right

moveleft:
	mov  dl, xpos    ; move chonker xpos to the column
	mov  dh, 11h     ; keep the chonker on row 11h        
	call set_cursor  ; place the cursor at the chonker position
	mov AL, 'X'      ; draw the tunnel as an "X"
	mov BH, 0        ; page 0
	mov BL, 7        ; 7=white
	mov CX,1         ; one character will print
	mov AH,09h       ; print char with attribute
	INT 10H          ; print the char
	DEC xpos         ; move left

	JMP OuterLoop

; is chonker at the RIGHT edge of the screen 
checkright:
	cmp xpos, 4FH	 ; see if chonker x coordinate equals that of right screen limit
	jne moveright	 ; if equal to 4FH, move right
	JMP OuterLoop    ; else continue the game without moving left or right

moveright:
	mov  dl, xpos    ; move chonker xpos to the column   
	mov  dh, 11h     ; keep the chonker on row 11h             
	call set_cursor  ; place the cursor at the chonker position
	mov AL, 'X'      ; draw the tunnel as an "X"
	mov BH, 0        ; page 0
	mov BL, 7        ; 7=white
	mov CX,1         ; one character will print
	mov AH,09h       ; print char with attribute
	INT 10H          ; print the char
	INC xpos         ; move right

	JMP OuterLoop    ; continue the game

terminate:

	mov AL, 1		 ; the following lines set up for the string print
	mov BH,0
	mov BL,6
	mov CX, nSize

	MOV DX, @data
	MOV ES, DX
	mov DH, 18h
	mov DL, 20h

	MOV BP, OFFSET msg

	mov AH, 13h              ; Print the "Chonker Terminated" message.
	int 10h


	MOV AX, 4C00h
	INT 21h
_main ENDP
END _main

