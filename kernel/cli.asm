; =============================================================================
; YOS -- a 64-bit OS written in Assembly for x86-64 systems
; Copyright (C) 2016-2017 Steven Yi -- see LICENSE.TXT
;
; COMMAND LINE INTERFACE
; =============================================================================

align 16
db 'DEBUG: CLI      '
align 16


os_command_line:
	mov rsi, prompt			; Prompt for input
	mov ebx, 0x00FF0000		; Red prompt in graphics mode
	mov [os_Font_Color], ebx
	call os_output
	mov ebx, 0x00FFFFFF		; White text in graphics mode
	mov [os_Font_Color], ebx

	mov rdi, cli_temp_string
	mov rcx, 250			; Limit the input to 250 characters
	call os_input
	jrcxz os_command_line		; os_input_string stores the number of characters received in RCX

	mov rsi, rdi
	call os_string_parse		; Remove extra spaces
	jrcxz os_command_line		; os_string_parse stores the number of words in RCX
	mov byte [app_argc], cl		; Store the number of words in the string

	; Break the contents of cli_temp_string into individual strings
	mov al, 0x20
	xor bl, bl
	call os_string_change_char

	mov rdi, cls_string		; 'CLS' entered?
	call os_string_compare
	jc near clear_screen

	mov rdi, ls_string		; 'DIR' entered?
	call os_string_compare
	jc near dir

	mov rdi, v_string		; 'v' entered?
	call os_string_compare
	jc near v_run

	mov rdi, ver_string		; 'VER' entered?
	call os_string_compare
	jc near print_ver

	mov rdi, exit_string		; 'EXIT' entered?
	call os_string_compare
	jc near exit

	mov rdi, help_string		; 'HELP' entered?
	call os_string_compare
	jc near print_help

	mov rdi, debug_string		; 'DEBUG' entered?
	call os_string_compare
	jc near debug

	mov rdi, reboot_string		; 'REBOOT' entered?
	call os_string_compare
	jc reboot

	mov rdi, testzone_string	; 'TESTZONE' entered?
	call os_string_compare
	jc near testzone

	; At this point it is not one of the built-in CLI functions. Prepare to check the file system.
	call os_file_open
	test rax, rax
	je fail
	inc rcx
	mov rdi, programlocation
	; Program found, load and execute
	call os_file_read
	call os_file_close
	mov rbx, programlocation	
	call rbx; Call the program just loaded
	jmp os_command_line		; Jump back to the CLI on program completion

v_run:
	call os_dump_sys_reg
	call os_debug_dump_reg

	mov rax, 0x7788
        ;call app_addr
        mov rbx, app_addr
	call rbx

	cmp rax, 0x1234
	je vv_success
	mov rsi, vv_err_msg
	call os_output
	jmp vv_exit
	
vv_success:
	mov rsi, vv_success_msg
	call os_output
vv_exit:
	jmp os_command_line

vv_err_msg     db 'error!',13,0
vv_success_msg db 'success!',13,0

fail:					; We didn't get a valid command or program name
	mov rsi, not_found_msg
	call os_output
	jmp os_command_line

print_help:
	mov rsi, help_text
	call os_output
	jmp os_command_line

clear_screen:
	call os_screen_clear
;	mov ax, 0x0018
;	call os_move_cursor
	jmp os_command_line

print_ver:
	mov rsi, version_msg
	call os_output
	jmp os_command_line

dir:
	mov rdi, cli_temp_string
	mov rsi, rdi
	call os_yfs_file_list
	call os_output
	jmp os_command_line

align 16
testzone:
	xchg bx, bx			; Bochs Magic Breakpoint

	mov qword [os_ClockCallback], 1
;	ud2

;	xor rax, rax
;	xor rbx, rcx
;	xor rcx, rcx
;	xor rdx, rdx
;	div rax

	jmp os_command_line

debug:
	mov rdx, 1			; argc
	call os_system_config
	cmp al, 1
	je debug_dump_reg		; If it is only one then do a register dump
	mov rcx, 16
	cmp al, 3			; Did we get at least 3?
	jl noamount			; If not no amount was specified
	mov al, 2
	call os_get_argv		; Get the amount of bytes to display
	mov rsi, rax
	call os_string_to_int		; Convert to an integer
	mov rcx, rax
noamount:
	mov al, 1
	call os_get_argv		; Get the starting memory address
	mov rsi, rax
	call os_hex_string_to_int
	mov rsi, rax
debug_default:
	call os_debug_dump_mem
	call os_print_newline

	jmp os_command_line

debug_dump_reg:
	call os_debug_dump_reg
	jmp os_command_line

exit:
	mov rdx, 256
	call os_system_misc
	ret

; Strings
	help_text		db 'Built-in commands: ls, cls, dbg, help, reboot, ver', 13, 0
	not_found_msg		db 'Command not found', 13, 0
	version_msg		db 'YOS v0.1.8', 13, 0

	ls_string		db 'ls', 0
	cls_string		db 'cls', 0
	v_string		db 'v', 0
	ver_string		db 'ver', 0
	exit_string		db 'exit', 0
	help_string		db 'help', 0
	debug_string		db 'dbg', 0
	reboot_string		db 'reboot', 0
	testzone_string		db 'tz', 0

	appextension:		db '.app', 0
	prompt:			db 'yos # ', 0

; -----------------------------------------------------------------------------
; os_string_find_char -- Find first location of character in a string
;  IN:	RSI = string location
;	AL  = character to find
; OUT:	RAX = location in string, or 0 if char not present
;	All other registers preserved
os_string_find_char:
	push rsi
	push rcx

	mov rcx, 1		; Counter -- start at first char
os_string_find_char_more:
	cmp byte [rsi], al
	je os_string_find_char_done
	cmp byte [rsi], 0
	je os_string_find_char_not_found
	inc rsi
	inc rcx
	jmp os_string_find_char_more

os_string_find_char_done:
	mov rax, rcx

	pop rcx
	pop rsi
	ret

os_string_find_char_not_found:
	pop rcx
	pop rsi
	xor eax, eax	; not found, set RAX to 0
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_string_change_char -- Change all instances of a character in a string
;  IN:	RSI = string location
;	AL  = character to replace
;	BL  = replacement character
; OUT:	All registers preserved
os_string_change_char:
	push rsi
	push rcx
	push rbx
	push rax

	mov cl, al
os_string_change_char_loop:
	mov byte al, [rsi]
	test al, al
	jz os_string_change_char_done
	cmp al, cl
	jne os_string_change_char_no_change
	mov byte [rsi], bl

os_string_change_char_no_change:
	inc rsi
	jmp os_string_change_char_loop

os_string_change_char_done:
	pop rax
	pop rbx
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_string_chomp -- Strip leading and trailing spaces from a string
;  IN:	RSI = string location
; OUT:	All registers preserved
os_string_chomp:
	push rsi
	push rdi
	push rcx
	push rax

	call os_string_length		; Quick check to see if there are any characters in the string
	jrcxz os_string_chomp_done	; No need to work on it if there is no data

	mov rdi, rsi			; RDI will point to the start of the string...
	push rdi			; ...while RSI will point to the "actual" start (without the spaces)
	add rdi, rcx			; os_string_length stored the length in RCX

os_string_chomp_findend:		; we start at the end of the string and move backwards until we don't find a space
	dec rdi
	cmp rsi, rdi			; Check to make sure we are not reading backward past the string start
	jg os_string_chomp_fail		; If so then fail (string only contained spaces)
	cmp byte [rdi], ' '
	je os_string_chomp_findend

	inc rdi				; we found the real end of the string so null terminate it
	mov byte [rdi], 0x00
	pop rdi

os_string_chomp_start_count:		; read through string until we find a non-space character
	cmp byte [rsi], ' '
	jne os_string_chomp_copy
	inc rsi
	jmp os_string_chomp_start_count

os_string_chomp_fail:			; In this situation the string is all spaces
	pop rdi				; We are about to bail out so make sure the stack is sane
	xor al, al
	stosb
	jmp os_string_chomp_done

; At this point RSI points to the actual start of the string (minus the leading spaces, if any)
; And RDI point to the start of the string

os_string_chomp_copy:		; Copy a byte from RSI to RDI one byte at a time until we find a NULL
	lodsb
	stosb
	test al, al
	jnz os_string_chomp_copy

os_string_chomp_done:
	pop rax
	pop rcx
	pop rdi
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_string_parse -- Parse a string into individual words
;  IN:	RSI = Address of string
; OUT:	RCX = word count
; Note:	This function will remove "extra" white-space in the source string
;	"This is  a test. " will update to "This is a test."
os_string_parse:
	push rsi
	push rdi
	push rax

	xor ecx, ecx			; RCX is our word counter
	mov rdi, rsi

	call os_string_chomp		; Remove leading and trailing spaces

	cmp byte [rsi], 0x00		; Check the first byte
	je os_string_parse_done		; If it is a null then bail out
	inc rcx				; At this point we know we have at least one word

os_string_parse_next_char:
	lodsb
	stosb
	test al, al			; Check if we are at the end
	jz os_string_parse_done		; If so then bail out
	cmp al, ' '			; Is it a space?
	je os_string_parse_found_a_space
	jmp os_string_parse_next_char	; If not then grab the next char

os_string_parse_found_a_space:
	lodsb				; We found a space.. grab the next char
	cmp al, ' '			; Is it a space as well?
	jne os_string_parse_no_more_spaces
	jmp os_string_parse_found_a_space

os_string_parse_no_more_spaces:
	dec rsi				; Decrement so the next lodsb will read in the non-space
	inc rcx
	jmp os_string_parse_next_char

os_string_parse_done:
	pop rax
	pop rdi
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_string_append -- Append a string to an existing string
;  IN:	RSI = String to be appended
;	RDI = Destination string
; OUT:	All registers preserved
; Note:	It is up to the programmer to ensure that there is sufficient space in the destination
os_string_append:
	push rsi
	push rdi
	push rcx

	xchg rsi, rdi
	call os_string_length
	xchg rsi, rdi
	add rdi, rcx
	call os_string_copy

	pop rcx
	pop rdi
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_hex_string_to_int -- Convert up to 8 hexascii to bin
;  IN:	RSI = Location of hex asciiz string
; OUT:	RAX = binary value of hex string
;	All other registers preserved
os_hex_string_to_int:
	push rsi
	push rcx
	push rbx

	cld
	xor ebx, ebx
os_hex_string_to_int_loop:
	lodsb
	mov cl, 4
	cmp al, 'a'
	jb os_hex_string_to_int_ok
	sub al, 0x20				; convert to upper case if alpha
os_hex_string_to_int_ok:
	sub al, '0'				; check if legal
	jc os_hex_string_to_int_exit		; jump if out of range
	cmp al, 9
	jle os_hex_string_to_int_got		; jump if number is 0-9
	sub al, 7				; convert to number from A-F or 10-15
	cmp al, 15				; check if legal
	ja os_hex_string_to_int_exit		; jump if illegal hex char
os_hex_string_to_int_got:
	shl rbx, cl
	or bl, al
	jmp os_hex_string_to_int_loop
os_hex_string_to_int_exit:
	mov rax, rbx				; integer value stored in RBX, move to RAX

	pop rbx
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; os_yfs_file_list -- Generate a list of files on disk
; IN:	RDI = location to store list
; OUT:	RDI = pointer to end of list
os_yfs_file_list:
	push rdi
	push rsi
	push rcx
	push rbx
	push rax

	mov rsi, Disk_Size_MSG
	call os_string_length
	call os_string_copy
	add rdi, rcx

	mov eax, [hd1_size]
	call os_int_to_string
	dec rdi
	xor al, al

	mov rsi, MiB_MSG
	call os_string_length
	call os_string_copy
	add rdi, rcx

	mov rsi, List_MSG
	call os_string_length
	call os_string_copy
	add rdi, rcx

	mov rsi, yfs_directory
	mov rbx, rsi

os_yfs_list_next:
	cmp byte [rbx], 0x00
	je os_yfs_list_done

	cmp byte [rbx], 0x01
	jle os_yfs_list_skip

	mov rsi, rbx
	call os_string_length
	call os_string_copy
	add rdi, rcx

	sub rcx, 34
	neg rcx
	mov al, ' '
	rep stosb

	mov rax, [rbx + NuFS_DirEnt.size]
	call os_int_to_string
	dec rdi

	sub rcx, 20		; 20 ?
	neg rcx
	mov al, ' '
	rep stosb

	mov rax, [rbx + NuFS_DirEnt.reserved]
	add rax, rax
	call os_int_to_string
	dec rdi
	mov al, 13
	stosb

os_yfs_list_skip:
	add rbx, 64
	cmp rbx, yfs_directory + 0x1000
	jne os_yfs_list_next

os_yfs_list_done:
	xor al, al
	stosb

	pop rax
	pop rbx
	pop rcx
	pop rsi
	pop rdi

	ret

Disk_Size_MSG: db 'Disk Size: ', 0
MiB_MSG: db ' MiB', 13, 0
List_MSG: db 'Name                            | Size (Byte)        | Reserved (MiB)', 13, 0
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
