//
//  efi_cpu_arch.h
//
//  Created by Gwynne Raskind on 3/9/14.
//  Copyright (c) 2014 Gwynne Raskind. All rights reserved.
//

#ifndef EFI_efi_cpu_arch_h
#define EFI_efi_cpu_arch_h

#include "efi_types.h"
#include "efi_misc.h"

extern EFI_GUID	EFI_CPU_ARCH_PROTOCOL_GUID;

EFI_GUID
		EFI_CPU_ARCH_PROTOCOL_GUID					= { 0x26baccb1, 0x6f42, 0x11d4, { 0xbc, 0xe7, 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 } };

typedef enum {
	EfiCpuFlushTypeWriteBackInvalidate,
	EfiCpuFlushTypeWriteBack,
	EfiCpuFlushTypeInvalidate,
	EfiCpuMaxFlushType,
} EFI_CPU_FLUSH_TYPE;

typedef enum {
	EfiCpuInit,
	EfiCpuMaxInitType,
} EFI_CPU_INIT_TYPE;

typedef INTN EFI_EXCEPTION_TYPE;

enum {
	EXCEPT_X64_DIVIDE_ERROR,
	EXCEPT_X64_DEBUG,
	EXCEPT_X64_NMI,
	EXCEPT_X64_BREAKPOINT,
	EXCEPT_X64_OVERFLOW,
	EXCEPT_X64_BOUND,
	EXCEPT_X64_INVALID_OPCODE,
	EXCEPT_X64_DOUBLE_FAULT,
	EXCEPT_X64_INVALID_TSS,
	EXCEPT_X64_SEG_NOT_PRESENT,
	EXCEPT_X64_STACK_FAULT,
	EXCEPT_X64_GP_FAULT,
	EXCEPT_X64_PAGE_FAULT,
	EXCEPT_X64_FP_ERROR,
	EXCEPT_X64_ALIGNMENT_CHECK,
	EXCEPT_X64_MACHINE_CHECK,
	EXCEPT_X64_SIMD
};

typedef struct {
	UINT16					Fcw, Fsw, Ftw;
	UINT16					Opcode;
	UINT64					Rip;
	UINT64					DataOffset;
	UINT8					Reserved1[8];
	UINT8					St0Mm0[10], Reserved2[6];
	UINT8					St1Mm1[10], Reserved3[6];
	UINT8					St2Mm2[10], Reserved4[6];
	UINT8					St3Mm3[10], Reserved5[6];
	UINT8					St4Mm4[10], Reserved6[6];
	UINT8					St5Mm5[10], Reserved7[6];
	UINT8					St6Mm6[10], Reserved8[6];
	UINT8					St7Mm7[10], Reserved9[6];
	UINT8					Xmm0[16], Xmm1[16], Xmm2[16], Xmm3[16], Xmm4[16], Xmm5[16], Xmm6[16], Xmm7[16];
	UINT8					Reserved11[14 * 16];
} EFI_FX_SAVE_STATE_X64;

typedef struct {
	UINT64						ExceptionData;
	EFI_FX_SAVE_STATE_X64		FxSaveState;
	UINT64						Dr0, Dr1, Dr2, Dr3, Dr6, Dr7;
	UINT64						Cr0, Cr1, Cr2, Cr3, Cr4, Cr8;
	UINT64						Rflags;
	UINT64						Ldtr, Tr;
	UINT64						Gdtr[2], Idtr[2];
	UINT64						Rip;
	UINT64						Gs, Fs, Es, Ds, Cs, Ss;
	UINT64						Rdi, Rsi, Rbp, Rsp, Rbx, Rdx, Rcx, Rax;
	UINT64						R8, R9, R10, R11, R12, R13, R14, R15;
} EFI_SYSTEM_CONTEXT_X64;

typedef union {
	EFI_SYSTEM_CONTEXT_X64 *SystemContextX64;
} EFI_SYSTEM_CONTEXT;

typedef VOID (*EFI_CPU_INTERRUPT_HANDLER)(IN EFI_EXCEPTION_TYPE, IN EFI_SYSTEM_CONTEXT);

typedef struct EFI_CPU_ARCH_PROTOCOL {
	EFI_STATUS					(EFIAPI *FlushDataCache)(IN const struct EFI_CPU_ARCH_PROTOCOL *, IN EFI_PHYSICAL_ADDRESS, IN UINT64, IN EFI_CPU_FLUSH_TYPE);
	EFI_STATUS					(EFIAPI *EnableInterrupt)(IN const struct EFI_CPU_ARCH_PROTOCOL *);
	EFI_STATUS					(EFIAPI *DisableInterrupt)(IN const struct EFI_CPU_ARCH_PROTOCOL *);
	EFI_STATUS					(EFIAPI *GetInterruptState)(IN const struct EFI_CPU_ARCH_PROTOCOL *, OUT BOOLEAN *);
	EFI_STATUS					(EFIAPI *Init)(IN const struct EFI_CPU_ARCH_PROTOCOL *, IN EFI_CPU_INIT_TYPE);
	EFI_STATUS					(EFIAPI *RegisterInterruptHandler)(IN const struct EFI_CPU_ARCH_PROTOCOL *, IN EFI_EXCEPTION_TYPE, IN EFI_CPU_INTERRUPT_HANDLER);
	EFI_STATUS					(EFIAPI *GetTimerValue)(IN const struct EFI_CPU_ARCH_PROTOCOL *, IN UINT32, OUT UINT64 *, OUT UINT64 * OPTIONAL);
	EFI_STATUS					(EFIAPI *SetMemoryAttributes)(IN const struct EFI_CPU_ARCH_PROTOCOL *, IN EFI_PHYSICAL_ADDRESS, IN UINT64, IN UINT64);
	UINT32						NumberOfTimers;
	UINT32						DmaBufferAlignment;
} EFI_CPU_ARCH_PROTOCOL;

#endif
