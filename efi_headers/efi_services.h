//
//  efi_services.h
//
//  Created by Gwynne Raskind on 3/9/14.
//  Copyright (c) 2014 Gwynne Raskind. All rights reserved.
//

#ifndef EFI_efi_services_h
#define EFI_efi_services_h

#include "efi_types.h"
#include "efi_filesystem.h"
#include "efi_simple_text.h"

#define EFI_SYSTEM_TABLE_SIGNATURE		0x5453595320494249 // 'IBI SYST'
#define EFI_BOOT_SERVICES_SIGNATURE		0x56524553544f4f42 // 'BOOTSERV'
#define EFI_RUNTIME_SERVICES_SIGNATURE	0x56524553544e5552 // 'RUNTSERV'

enum {
	EFI_1_02_SYSTEM_TABLE_REVISION = 0x00010002,
	EFI_1_10_SYSTEM_TABLE_REVISION = 0x0001000a,
	EFI_2_00_SYSTEM_TABLE_REVISION = 0x00020000,
	EFI_2_10_SYSTEM_TABLE_REVISION = 0x0002000a,
	EFI_2_20_SYSTEM_TABLE_REVISION = 0x00020014,
	EFI_2_30_SYSTEM_TABLE_REVISION = 0x0002001e,
	EFI_2_31_SYSTEM_TABLE_REVISION = 0x0002001f,
	EFI_SYSTEM_TABLE_REVISION = EFI_2_31_SYSTEM_TABLE_REVISION,
	EFI_SPECIFICATION_VERSION = EFI_SYSTEM_TABLE_REVISION,
	EFI_BOOT_SERVICES_REVISION = EFI_SPECIFICATION_VERSION,
	EFI_RUNTIME_SERVICES_REVISION = EFI_SPECIFICATION_VERSION,
};

typedef struct {
	UINT64				Signature;
	UINT32				Revision;
	UINT32				HeaderSize;
	UINT32				CRC32;
	UINT32				Reserved;
} EFI_TABLE_HEADER;

typedef struct {
	EFI_TABLE_HEADER	Hdr;
	EFI_TPL				(EFIAPI *RaiseTPL)(IN EFI_TPL); // 0x18
	VOID				(EFIAPI *RestoreTPL)(IN EFI_TPL); // 0x20
	EFI_STATUS			(EFIAPI *AllocatePages)(IN EFI_ALLOCATE_TYPE, IN EFI_MEMORY_TYPE, IN UINTN, IN OUT EFI_PHYSICAL_ADDRESS *); // 0x28
	EFI_STATUS			(EFIAPI *FreePages)(IN EFI_PHYSICAL_ADDRESS, IN UINTN); // 0x30
	EFI_STATUS			(EFIAPI *GetMemoryMap)(IN OUT UINTN *, IN OUT EFI_MEMORY_DESCRIPTOR *, OUT UINTN *, OUT UINTN *, OUT UINT32 *); // 0x38
	EFI_STATUS			(EFIAPI *AllocatePool)(IN EFI_MEMORY_TYPE, IN UINTN, OUT VOID **); // 0x40
	EFI_STATUS			(EFIAPI *FreePool)(IN VOID *); // 0x48
	EFI_STATUS			(EFIAPI *CreateEvent)(IN UINT32, IN EFI_TPL, IN EFI_EVENT_NOTIFY, IN VOID *, OUT EFI_EVENT *); // 0x50
	EFI_STATUS			(EFIAPI *SetTimer)(IN EFI_EVENT, IN EFI_TIMER_DELAY, IN UINT64); // 0x58
	EFI_STATUS			(EFIAPI *WaitForEvent)(IN UINTN, IN EFI_EVENT *, OUT UINTN *); // 0x60
	EFI_STATUS			(EFIAPI *SignalEvent)(IN EFI_EVENT); // 0x68
	EFI_STATUS			(EFIAPI *CloseEvent)(IN EFI_EVENT); // 0x70
	EFI_STATUS			(EFIAPI *CheckEvent)(IN EFI_EVENT); // 0x78
	EFI_STATUS			(EFIAPI *InstallProtocolInterface)(IN OUT EFI_HANDLE *, IN EFI_GUID *, IN EFI_INTERFACE_TYPE, IN VOID *); // 0x80
	EFI_STATUS			(EFIAPI *ReinstallProtocolInterface)(IN EFI_HANDLE, IN EFI_GUID *, IN VOID *, IN VOID *); // 0x88
	EFI_STATUS			(EFIAPI *UninstallProtocolInterface)(IN EFI_HANDLE, IN EFI_GUID *, IN VOID *); // 0x90
	EFI_STATUS			(EFIAPI *HandleProtocol)(IN EFI_HANDLE, IN EFI_GUID *, OUT VOID **); // 0x98
	VOID				*Reserved; // 0xa0
	EFI_STATUS			(EFIAPI *RegisterProtocolNotify)(IN EFI_GUID *, IN EFI_EVENT, OUT VOID **); // 0xa8
	EFI_STATUS			(EFIAPI *LocateHandle)(IN EFI_LOCATE_SEARCH_TYPE, IN EFI_GUID * OPTIONAL, IN VOID * OPTIONAL, IN OUT UINTN *, OUT EFI_HANDLE *); // 0xb0
	EFI_STATUS			(EFIAPI *LocateDevicePath)(IN EFI_GUID *, IN OUT EFI_DEVICE_PATH_PROTOCOL **, OUT EFI_HANDLE *); // 0xb8
	EFI_STATUS			(EFIAPI *InstallConfigurationTable)(IN EFI_GUID *, IN VOID *); // 0xc0
	EFI_STATUS			(EFIAPI *LoadImage)(IN BOOLEAN, IN EFI_HANDLE, IN EFI_DEVICE_PATH_PROTOCOL *, IN VOID * OPTIONAL, IN UINTN, OUT EFI_HANDLE *); // 0xc8
	EFI_STATUS			(EFIAPI *StartImage)(IN EFI_HANDLE, OUT UINTN *, OUT CHAR16 ** OPTIONAL); // 0xd0
	EFI_STATUS			(EFIAPI *Exit)(IN EFI_HANDLE, IN EFI_STATUS, IN UINTN, IN CHAR16 * OPTIONAL); // 0xd8
	EFI_STATUS			(EFIAPI *UnloadImage)(IN EFI_HANDLE); // 0xe0
	EFI_STATUS			(EFIAPI *ExitBootServices)(IN EFI_HANDLE, IN UINTN); // 0xe8
	EFI_STATUS			(EFIAPI *GetNextMonotonicCount)(OUT UINT64 *); // 0xf0
	EFI_STATUS			(EFIAPI *Stall)(IN UINTN); // 0xf8
	EFI_STATUS			(EFIAPI *SetWatchdogTimer)(IN UINTN, IN UINT64, IN UINTN, IN CHAR16 * OPTIONAL); // 0x100
	EFI_STATUS			(EFIAPI *ConnectController)(IN EFI_HANDLE, IN EFI_HANDLE * OPTIONAL, IN EFI_DEVICE_PATH_PROTOCOL * OPTIONAL, IN BOOLEAN); // 0x108
	EFI_STATUS			(EFIAPI *DisconnectController)(IN EFI_HANDLE, IN EFI_HANDLE OPTIONAL, IN EFI_HANDLE OPTIONAL); // 0x110
	EFI_STATUS			(EFIAPI *OpenProtocol)(IN EFI_HANDLE, IN EFI_GUID *, OUT VOID ** OPTIONAL, IN EFI_HANDLE, IN EFI_HANDLE, IN UINT32); // 0x118
	EFI_STATUS			(EFIAPI *CloseProtocol)(IN EFI_HANDLE, IN EFI_GUID *, IN EFI_HANDLE, IN EFI_HANDLE); // 0x120
	EFI_STATUS			(EFIAPI *OpenProtocolInformation)(IN EFI_HANDLE, IN EFI_GUID *, OUT EFI_OPEN_PROTOCOL_INFORMATION_ENTRY **, OUT UINTN *); // 0x128
	EFI_STATUS			(EFIAPI *ProtocolsPerHandle)(IN EFI_HANDLE, OUT EFI_GUID ***, OUT UINTN *); // 0x130
	EFI_STATUS			(EFIAPI *LocateHandleBuffer)(IN EFI_LOCATE_SEARCH_TYPE, IN EFI_GUID * OPTIONAL, IN VOID * OPTIONAL, IN OUT UINTN *, OUT EFI_HANDLE **); // 0x138
	EFI_STATUS			(EFIAPI *LocateProtocol)(IN EFI_GUID *, IN VOID * OPTIONAL, OUT VOID **); // 0x140
	EFI_STATUS			(EFIAPI *InstallMultipleProtocolInterfaces)(IN OUT EFI_HANDLE *, ...); // 0x148
	EFI_STATUS			(EFIAPI *UninstallMultipleProtocolInterfaces)(IN EFI_HANDLE, ...); // 0x150
	EFI_STATUS			(EFIAPI *CalculateCrc32)(IN VOID *, IN UINTN, OUT UINT32 *); // 0x158
	VOID				(EFIAPI *CopyMem)(IN VOID *, IN VOID *, IN UINTN); // 0x160
	VOID				(EFIAPI *SetMem)(IN VOID *, IN UINTN, IN UINT8); // 0x168
	EFI_STATUS			(EFIAPI *CreateEventEx)(IN UINT32, IN EFI_TPL, IN EFI_EVENT_NOTIFY, IN CONST VOID * OPTIONAL, IN CONST EFI_GUID * OPTIONAL, OUT EFI_EVENT *); // 0x170
} EFI_BOOT_SERVICES;

typedef struct {
	EFI_TABLE_HEADER	Hdr;
	EFI_STATUS			(EFIAPI *GetTime)(OUT EFI_TIME *, OUT EFI_TIME_CAPABILITIES * OPTIONAL); // 0x18
	EFI_STATUS			(EFIAPI *SetTime)(IN EFI_TIME *); // 0x20
	EFI_STATUS			(EFIAPI *GetWakeupTime)(OUT BOOLEAN *, OUT BOOLEAN *, OUT EFI_TIME *); // 0x28
	EFI_STATUS			(EFIAPI *SetWakeupTime)(IN BOOLEAN, IN EFI_TIME * OPTIONAL); // 0x30
	EFI_STATUS			(EFIAPI *SetVirtualAddressMap)(IN UINTN, IN UINTN, IN UINT32, IN EFI_MEMORY_DESCRIPTOR *); // 0x38
	EFI_STATUS			(EFIAPI *ConvertPointer)(IN UINTN, IN VOID **); // 0x40
	EFI_STATUS			(EFIAPI *GetVariable)(IN CHAR16 *, IN EFI_GUID *, OUT UINT32 * OPTIONAL, IN OUT UINTN *, OUT VOID *); // 0x48
	EFI_STATUS			(EFIAPI *GetNextVariableName)(IN OUT UINTN *, IN OUT CHAR16 *, IN OUT EFI_GUID *); // 0x50
	EFI_STATUS			(EFIAPI *SetVariable)(IN CHAR16 *, IN EFI_GUID *, IN UINT32, IN UINTN, IN VOID *); // 0x58
	EFI_STATUS			(EFIAPI *GetNextHighMonotonicCount)(OUT UINT32 *); // 0x60
	EFI_STATUS			(EFIAPI *ResetSystem)(IN EFI_RESET_TYPE, IN EFI_STATUS, IN UINTN, IN VOID * OPTIONAL); // 0x68
	EFI_STATUS			(EFIAPI *UpdateCapsule)(IN EFI_CAPSULE_HEADER **, IN UINTN, IN EFI_PHYSICAL_ADDRESS OPTIONAL); // 0x70
	EFI_STATUS			(EFIAPI *QueryCapsuleCapabilities)(IN EFI_CAPSULE_HEADER **, IN UINTN, OUT UINT64, OUT EFI_RESET_TYPE *); // 0x78
	EFI_STATUS			(EFIAPI *QueryVariableInfo)(IN UINT32, OUT UINT64 *, OUT UINT64 *, OUT UINT64 *); // 0x80
} EFI_RUNTIME_SERVICES;

typedef struct {
	EFI_GUID			VendorGuid;
	VOID				*VendorTable;
} EFI_CONFIGURATION_TABLE;

typedef struct {
	EFI_TABLE_HEADER						Hdr;
	CHAR16									*FirmwareVendor;			// 24 - 0x18
	UINT32									FirmwareRevision;			// 32 - 0x20
	UINT32									__Padding;
	EFI_HANDLE								ConsoleInHandle;			// 40 - 0x28
	EFI_SIMPLE_TEXT_INPUT_PROTOCOL			*ConIn;						// 48 - 0x30
	EFI_HANDLE								ConsoleOutHandle;			// 56 - 0x38
	EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL			*ConOut;					// 64 - 0x40
	EFI_HANDLE								StandardErrorHandle;
	EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL			*StdErr;
	EFI_RUNTIME_SERVICES					*RuntimeServices;
	EFI_BOOT_SERVICES						*BootServices;
	UINTN									NumberOfTableEntries;
	EFI_CONFIGURATION_TABLE					*ConfigurationTable;
} EFI_SYSTEM_TABLE;

#endif
