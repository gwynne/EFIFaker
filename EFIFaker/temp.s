_block_tramp_dispatch:
	pop    %r11
	and    $0xfffffffffffffff8, %r11 // truncate to the trampoline start (each is 8 bytes)
	sub    $0x1000, %r11 // load the config location

	push %rbx
	push %rbp
	push %rdi
	push %rsi
	push %r12
	push %r13
	push %r14
	push %r15

	// Reconfigure MS ABI -> SysV ABI, shift first param up, save its caller-saved registers
	mov		%rcx, %rsi
	mov		%rdx, %rdx
	mov		%r8, %rcx
	mov		%r9, %r8
	mov		0x40(%rsp), %r9
	push	%r9
	mov		0x50(%rsp), %r9

	// Load the block reference from the config page, and move to the first parameter
	mov   (%r11), %rdi

	// Jump to the block fptr; can't tail call because we need to tidy the stack (eww)
	call	*0x10(%rdi)

	add		$0x8, %rsp
	pop %r15
	pop %r14
	pop %r13
	pop %r12
	pop %rsi
	pop %rdi
	pop %rbp
	pop %rbx

	ret

