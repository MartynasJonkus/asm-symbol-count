.model small

.stack 100h

.data
    ;File names and handles
    readFile    db 255 dup (?)
    readHandle  dw 0
    writeFile   db 255 dup (?)
    writeHandle dw 0
    
    ;Error and help messages
    error_message db 'Error!', 13, 10, '$'
    help_message  db 'Valid input is file.exe <input.txt> <output.txt>', 13, 10, '$'
    error_creating db 'Failed to create results file', 13, 10, '$'
    error_opening db 'Failed to open data file', 13, 10, '$'
    error_reading db 'Failed to read data file', 13, 10, '$'
    
    ;Arrays for input buffer and output symbol counts
    readBuffer db 255 dup (?)
    values     db 255 dup (0)
    
    ;Formatting and tools to output properly
    space db '   '
    entern db 13, 10, '$'
    temp db 0
    counter db 0    
     
.code
  start:
    mov ax, @data
    mov ds, ax

    call getFileNames
    
    call createFile
    
    call openRead
    
    ;Reads the buffer and counts the symbols in it until the buffer returns as empty
    ;ax shows the number of bytes the buffer has in it        
    readAndCalculate:            
    call readInputFile
    cmp ax, 0
    je done
    call count
    jmp readAndCalculate
          
    done:      
    call outputResult
       
      
      
;Gets the file names from the command line arguments whish start at ES:82h (skipping the space)
;Not needed to get argument byte count for this program     
getFileNames proc
    mov si, 82h
    mov di, 0 

    rFileLoop:
    mov dl, es:[si]
    
    cmp dl, 32
    je wFile
    cmp dl, 13
    je badInput
    cmp dl, 0
    je badInput
    mov readFile[di], dl

    inc si
    inc di
    jmp rFileLoop
     
     
    badInput:
    mov ah, 9
    mov dx, offset error_message
    int 21h

    mov ah, 9
    mov dx, offset help_message
    int 21h
    
    mov ax, 4C00h
    int 21h
              
              
    wFile:
    inc si
    mov di, 0
    
    wFileLoop:
    mov dl, es:[si]
    cmp dl, 13
    je endGetFileNames
    cmp dl, 0
    je endGetFileNames
    mov dl, es:[si]
    mov writeFile[di], dl

    inc si
    inc di
    jmp wFileLoop
    
    
    endGetFileNames:  
    ret
getFileNames endp


;Creates the result file with argument set to 0 (read-only)
;Gets the handle of the created file (opens it)
createFile proc 
    mov ah, 3Ch
    mov cx, 0
    mov dx, offset writeFile                         
    int 21h
    jc errorCreatingFile
    mov writeHandle, ax
    
    jmp endCreateFile
    
    
    errorCreatingFile:
    mov ah, 9
    mov dx, offset error_message
    int 21h
    
    mov ah, 9
    mov dx, offset error_creating
    int 21h
    
    mov ax, 4C00h
    int 21h
    
    
    endCreateFile:
    ret
createFile endp      
    

;Opens the existing source file and gets its handle
openRead proc    
    mov ah, 3dh 
    mov al, 00
    mov dx, offset readFile
    int 21h
    jc errorOpeningFile
    mov readHandle, ax
    
    jmp endReadWrite
    
    
    errorOpeningFile:
    mov ah, 9
    mov dx, offset error_message
    int 21h
    
    mov ah, 09
    mov dx, offset error_opening
    int 21h
    
    mov ax, 4C00h
    int 21h

    
    endReadWrite:
    ret
openRead endp


;Reads from the source file and fills the buffer with up to 255 symbols
readInputFile proc
    mov ah, 3Fh
    mov bx, readHandle
    mov cx, 255
    mov dx, offset readBuffer
    int 21h
    jc failedToRead   
                   
    ret 
    
                   
    failedToRead:
    mov ah, 9
    mov dx, offset error_message
    int 21h
    
    mov ah, 9
    mov dx, offset error_reading
    int 21h
    
    mov ax, 4C00h
    int 21h
readInputFile endp 
        

;Increments the value of each symbol in the values array everytime the symbol appears in the bufffer        
count proc
    mov cx, 0
    mov dx, 0
    mov di, offset readBuffer
    mov si, offset values
    
    countLoop:
    cmp cx, ax
    je endCount
    
    mov si, offset values
    mov dl, [di]
    add si, dx
    inc byte ptr [si]
    
    inc cx
    inc di
    jmp countLoop
    
    
    endCount:
    ret        
count endp
   

;Outputs the symbol (if it has a visual representation) and the decimal number of times it appears in the text  
outputResult proc
    mov si, offset counter
    mov bx, writeHandle
    mov di, offset values
    
    outputLoop:
    cmp byte ptr [di], 0
    je skip
    cmp byte ptr [si], 255
    je endOutput
    cmp byte ptr [si], 33
    jl noPrint
    
    ;Displays symbol if it has a visual representation (decimal value of the symbol is less than 33)
    mov ah, 40h
    mov bx, writeHandle
    mov cx, 1
    mov dx, si
    int 21h
    jc jmpTooBig
    
           
    noPrint:
    ;Prints a space between the symbol and its decimal count       
    mov ah, 40h
    mov bx, writeHandle
    mov cx, 3
    mov dx, offset space
    int 21h
    jc failedToWriteOrClose
    
    ;Prints the decimal value of the number of times a symbol has appeared
    mov ax, 0         
    mov al, byte ptr [di]          
    mov cx, 0
    mov dx, 0
    label1:
        cmp ax,0
        je print1     
        mov bx,10       
        div bx                 
        push dx             
        inc cx             
        mov dx, 0
        jmp label1
    print1:
        cmp cx,0
        je exit
         
        pop dx
         
        add dx, 48
        mov temp, dl
        
        push cx
        mov ah, 40h
        mov bx, writeHandle
        mov cx, 1
        mov dx, offset temp
        int 21h
        jc failedToWriteOrClose
        pop cx
         
        dec cx
        jmp print1
    exit:
      
    ;Prints a newline
    mov ah, 40h
    mov bx, writeHandle
    mov cx, 1
    mov dx, offset entern 
    int 21h
    jc failedToWriteOrClose
    
    skip:    
    inc byte ptr [si]
    inc di
    jmp outputLoop
    
    ;Relative jumps have a limited size so added a middle point    
    jmpTooBig:
    jmp failedToWriteOrClose
    
    
    ;Closes both the source and result files and returns control to the OS    
    endOutput:               
    mov ah, 3Eh
    mov bx, readHandle[0]
    int 21h    
    jc failedToWriteOrClose

    mov ah, 3Eh
    mov bx, writeHandle[0]
    int 21h
    jc failedToWriteOrClose
    
    mov ax, 4C00h
    int 21h
      
      
    failedToWriteOrClose:
    mov ah, 9
    mov dx, offset error_message
    int 21h
    
    mov ah, 9
    mov dx, offset help_message
    int 21h
    
    mov ax, 4C00h
    int 21h
outputResult endp 

  
end start