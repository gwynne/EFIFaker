//
//  efi_misc.h
//  EFI Test
//
//  Created by Gwynne Raskind on 3/9/14.
//  Copyright (c) 2014 Gwynne Raskind. All rights reserved.
//

#ifndef EFI_efi_misc_h
#define EFI_efi_misc_h

#include "efi_types.h"

enum {
	EFI_MEMORY_DESCRIPTOR_VERSION = 1,
};

typedef enum { TimerCancel, TimerPeriodic, TimerRelative } EFI_TIMER_DELAY;
typedef enum { AllocateAnyPages, AllocateMaxAddress, AllocateAddress, MaxAllocateType } EFI_ALLOCATE_TYPE;
typedef enum { EfiReservedMemoryType, EfiLoaderCode, EfiLoaderData, EfiBootServicesCode, EfiBootServicesData, EfiRuntimeServicesCode, EfiRuntimeServicesData,
			   EfiConventionalMemory, EfiUnusableMemory, EfiACPIReclaimMemory, EfiACPIMemoryNVS, EfiMemoryMappedIO, EfiMemoryMappedIOPortSpace,
			   EfiPalCode, EfiMaxMemoryType } EFI_MEMORY_TYPE;
typedef enum { EFI_NATIVE_INTERFACE } EFI_INTERFACE_TYPE;
typedef enum { AllHandles, ByRegisterNotify, ByProtocol } EFI_LOCATE_SEARCH_TYPE;
typedef enum { EfiResetCold, EfiResetWarm, EfiResetShutdown } EFI_RESET_TYPE;

typedef struct {
	UINT32						Type;
	UINT32						__Padding;
	EFI_PHYSICAL_ADDRESS		PhysicalStart;
	EFI_VIRTUAL_ADDRESS			VirtualStart;
	UINT64						NumberOfPages;
	UINT64						Attribute;
} EFI_MEMORY_DESCRIPTOR;

typedef struct {
	EFI_HANDLE					AgentHandle;
	EFI_HANDLE					ControllerHandle;
	UINT32						Attributes;
	UINT32						OpenCount;
} EFI_OPEN_PROTOCOL_INFORMATION_ENTRY;

typedef struct {
	UINT32						dwLength;
	UINT16						wRevision;
	UINT16						wCertificateType;
} WIN_CERTIFICATE;
typedef struct {
	WIN_CERTIFICATE				Hdr;
	EFI_GUID					CertType;
	UINT8						CertData[0];
} WIN_CERTIFICATE_UEFI_GUID;

typedef struct {
	UINT32						Resolution;
	UINT32						Accuracy;
	BOOLEAN						SetsToZero;
	UINT8						__Padding[3];
} EFI_TIME_CAPABILITIES;

typedef struct {
	UINT64						MonotonicCount;
	WIN_CERTIFICATE_UEFI_GUID	AuthInfo;
} EFI_VARIABLE_AUTHENTICATION;
typedef struct {
	EFI_TIME					TimeStamp;
	WIN_CERTIFICATE_UEFI_GUID	AuthInfo;
} EFI_VARIABLE_AUTHENTICATION_2;

typedef struct {
	UINT64						Length;
	union {
		EFI_PHYSICAL_ADDRESS	DataBlock;
		EFI_PHYSICAL_ADDRESS	ContinuationPointer;
	} Union;
} EFI_CAPSULE_BLOCK_DESCRIPTOR;
typedef struct {
	EFI_GUID					CapsuleGuid;
	UINT32						HeaderSize;
	UINT32						Flags;
	UINT32						CapsuleImageSize;
} EFI_CAPSULE_HEADER;

typedef struct {
	EFI_GUID					PackageListGuid;
	UINT32						PackageLength;
} EFI_HII_PACKAGE_LIST_HEADER;

typedef VOID (EFIAPI *EFI_EVENT_NOTIFY)(IN EFI_EVENT, IN VOID *);
typedef EFI_STATUS (EFIAPI *EFI_KEY_NOTIFY_FUNCTION)(IN EFI_KEY_DATA *);

typedef EFI_HII_PACKAGE_LIST_HEADER *EFI_HII_PACKAGE_LIST_PROTOCOL;

static const UINT32 crc32tab[256] = {
	0x00000000,0x77073096,0xee0e612c,0x990951ba,0x076dc419,0x706af48f,0xe963a535,0x9e6495a3,0x0edb8832,0x79dcb8a4,0xe0d5e91e,0x97d2d988,
	0x09b64c2b,0x7eb17cbd,0xe7b82d07,0x90bf1d91,0x1db71064,0x6ab020f2,0xf3b97148,0x84be41de,0x1adad47d,0x6ddde4eb,0xf4d4b551,0x83d385c7,
	0x136c9856,0x646ba8c0,0xfd62f97a,0x8a65c9ec,0x14015c4f,0x63066cd9,0xfa0f3d63,0x8d080df5,0x3b6e20c8,0x4c69105e,0xd56041e4,0xa2677172,
	0x3c03e4d1,0x4b04d447,0xd20d85fd,0xa50ab56b,0x35b5a8fa,0x42b2986c,0xdbbbc9d6,0xacbcf940,0x32d86ce3,0x45df5c75,0xdcd60dcf,0xabd13d59,
	0x26d930ac,0x51de003a,0xc8d75180,0xbfd06116,0x21b4f4b5,0x56b3c423,0xcfba9599,0xb8bda50f,0x2802b89e,0x5f058808,0xc60cd9b2,0xb10be924,
	0x2f6f7c87,0x58684c11,0xc1611dab,0xb6662d3d,0x76dc4190,0x01db7106,0x98d220bc,0xefd5102a,0x71b18589,0x06b6b51f,0x9fbfe4a5,0xe8b8d433,
	0x7807c9a2,0x0f00f934,0x9609a88e,0xe10e9818,0x7f6a0dbb,0x086d3d2d,0x91646c97,0xe6635c01,0x6b6b51f4,0x1c6c6162,0x856530d8,0xf262004e,
	0x6c0695ed,0x1b01a57b,0x8208f4c1,0xf50fc457,0x65b0d9c6,0x12b7e950,0x8bbeb8ea,0xfcb9887c,0x62dd1ddf,0x15da2d49,0x8cd37cf3,0xfbd44c65,
	0x4db26158,0x3ab551ce,0xa3bc0074,0xd4bb30e2,0x4adfa541,0x3dd895d7,0xa4d1c46d,0xd3d6f4fb,0x4369e96a,0x346ed9fc,0xad678846,0xda60b8d0,
	0x44042d73,0x33031de5,0xaa0a4c5f,0xdd0d7cc9,0x5005713c,0x270241aa,0xbe0b1010,0xc90c2086,0x5768b525,0x206f85b3,0xb966d409,0xce61e49f,
	0x5edef90e,0x29d9c998,0xb0d09822,0xc7d7a8b4,0x59b33d17,0x2eb40d81,0xb7bd5c3b,0xc0ba6cad,0xedb88320,0x9abfb3b6,0x03b6e20c,0x74b1d29a,
	0xead54739,0x9dd277af,0x04db2615,0x73dc1683,0xe3630b12,0x94643b84,0x0d6d6a3e,0x7a6a5aa8,0xe40ecf0b,0x9309ff9d,0x0a00ae27,0x7d079eb1,
	0xf00f9344,0x8708a3d2,0x1e01f268,0x6906c2fe,0xf762575d,0x806567cb,0x196c3671,0x6e6b06e7,0xfed41b76,0x89d32be0,0x10da7a5a,0x67dd4acc,
	0xf9b9df6f,0x8ebeeff9,0x17b7be43,0x60b08ed5,0xd6d6a3e8,0xa1d1937e,0x38d8c2c4,0x4fdff252,0xd1bb67f1,0xa6bc5767,0x3fb506dd,0x48b2364b,
	0xd80d2bda,0xaf0a1b4c,0x36034af6,0x41047a60,0xdf60efc3,0xa867df55,0x316e8eef,0x4669be79,0xcb61b38c,0xbc66831a,0x256fd2a0,0x5268e236,
	0xcc0c7795,0xbb0b4703,0x220216b9,0x5505262f,0xc5ba3bbe,0xb2bd0b28,0x2bb45a92,0x5cb36a04,0xc2d7ffa7,0xb5d0cf31,0x2cd99e8b,0x5bdeae1d,
	0x9b64c2b0,0xec63f226,0x756aa39c,0x026d930a,0x9c0906a9,0xeb0e363f,0x72076785,0x05005713,0x95bf4a82,0xe2b87a14,0x7bb12bae,0x0cb61b38,
	0x92d28e9b,0xe5d5be0d,0x7cdcefb7,0x0bdbdf21,0x86d3d2d4,0xf1d4e242,0x68ddb3f8,0x1fda836e,0x81be16cd,0xf6b9265b,0x6fb077e1,0x18b74777,
	0x88085ae6,0xff0f6a70,0x66063bca,0x11010b5c,0x8f659eff,0xf862ae69,0x616bffd3,0x166ccf45,0xa00ae278,0xd70dd2ee,0x4e048354,0x3903b3c2,
	0xa7672661,0xd06016f7,0x4969474d,0x3e6e77db,0xaed16a4a,0xd9d65adc,0x40df0b66,0x37d83bf0,0xa9bcae53,0xdebb9ec5,0x47b2cf7f,0x30b5ffe9,
	0xbdbdf21c,0xcabac28a,0x53b39330,0x24b4a3a6,0xbad03605,0xcdd70693,0x54de5729,0x23d967bf,0xb3667a2e,0xc4614ab8,0x5d681b02,0x2a6f2b94,
	0xb40bbe37,0xc30c8ea1,0x5a05df1b,0x2d02ef8d,
};

enum {
	EFI_MEMORY_UC			= 0x0000000000000001,
	EFI_MEMORY_WC			= 0x0000000000000002,
	EFI_MEMORY_WT			= 0x0000000000000004,
	EFI_MEMORY_WB			= 0x0000000000000008,
	EFI_MEMORY_UCE			= 0x0000000000000010,
	EFI_MEMORY_WP			= 0x0000000000001000,
	EFI_MEMORY_RP			= 0x0000000000002000,
	EFI_MEMORY_XP			= 0x0000000000004000,
	EFI_MEMORY_RUNTIME		= 0x8000000000000000,
};

enum {
	TPL_APPLICATION = 4,
	TPL_CALLBACK = 8,
	TPL_NOTIFY = 16,
	TPL_HIGH_LEVEL = 31,
	EVT_TIMER = 0x80000000,
	EVT_RUNTIME = 0x40000000,
	EVT_NOTIFY_WAIT = 0x00000100,
	EVT_NOTIFY_SIGNAL = 0x00000200,
	EVT_SIGNAL_EXIT_BOOT_SERVICES = 0x00000201,
	EVT_SIGNAL_VIRTUAL_ADDRESS_CHANGE = 0x60000202,
	EFI_HII_PACKAGE_TYPE_ALL						= 0x00,
	EFI_HII_PACKAGE_TYPE_GUID						= 0x01,
	EFI_HII_PACKAGE_FORMS							= 0x02,
	EFI_HII_PACKAGE_STRINGS							= 0x04,
	EFI_HII_PACKAGE_FONTS							= 0x05,
	EFI_HII_PACKAGE_IMAGES							= 0x06,
	EFI_HII_PACKAGE_SIMPLE_FONTS					= 0x07,
	EFI_HII_PACKAGE_DEVICE_PATH						= 0x08,
	EFI_HII_PACKAGE_KEYBOARD_LAYOUT					= 0x09,
	EFI_HII_PACKAGE_ANIMATIONS						= 0x0A,
	EFI_HII_PACKAGE_END								= 0xDF,
	EFF_HII_PACKAGE_TYPE_SYSTEM_BEGIN				= 0xE0,
	EFI_HII_PACKAGE_TYPE_SYSTEM_END					= 0xFF,
	EFI_SHIFT_STATE_VALID							= 0x80000000,
	EFI_RIGHT_SHIFT_PRESSED							= 0x00000001,
	EFI_LEFT_SHIFT_PRESSED							= 0x00000002,
	EFI_RIGHT_CONTROL_PRESSED						= 0x00000004,
	EFI_LEFT_CONTROL_PRESSED						= 0x00000008,
	EFI_RIGHT_ALT_PRESSED							= 0x00000010,
	EFI_LEFT_ALT_PRESSED							= 0x00000020,
	EFI_RIGHT_LOGO_PRESSED							= 0x00000040,
	EFI_LEFT_LOGO_PRESSED							= 0x00000080,
	EFI_MENU_KEY_PRESSED							= 0x00000100,
	EFI_SYS_REQ_PRESSED								= 0x00000200,
	EFI_TOGGLE_STATE_VALID							= 0x80,
	EFI_KEY_STATE_EXPOSED							= 0x40,
	EFI_SCROLL_LOCK_ACTIVE							= 0x01,
	EFI_NUM_LOCK_ACTIVE								= 0x02,
	EFI_CAPS_LOCK_ACTIVE							= 0x04,
	EFI_VARIABLE_NON_VOLATILE						= 0x00000001,
	EFI_VARIABLE_BOOTSERVICE_ACCESS					= 0x00000002,
	EFI_VARIABLE_RUNTIME_ACCESS						= 0x00000004,
	EFI_VARIABLE_HARDWARE_ERROR_RECORD				= 0x00000008,
	EFI_VARIABLE_AUTHENTICATED_WRITE_ACCESS			= 0x00000010,
	EFI_VARIABLE_TIME_BASED_AUTHENTICATED_WRITE_ACCESS	= 0x00000020,
	EFI_VARIABLE_APPEND_WRITE						= 0x00000040,
	EFI_TIME_ADJUST_DAYLIGHT						= 0x01,
	EFI_TIME_IN_DAYLIGHT							= 0x02,
	EFI_UNSPECIFIED_TIMEZONE						= 0x07ff,
	EFI_OPTIONAL_PTR								= 0x00000001,
	CAPSULE_FLAGS_PERSIST_ACROSS_RESET				= 0x00010000,
	CAPSULE_FLAGS_POPULATE_SYSTEM_TABLE				= 0x00020000,
	CAPSULE_FLAGS_INITIATE_RESET					= 0x00040000,
	EFI_OPEN_PROTOCOL_BY_HANDLE_PROTOCOL			= 0x00000001,
	EFI_OPEN_PROTOCOL_GET_PROTOCOL					= 0x00000002,
	EFI_OPEN_PROTOCOL_TEST_PROTOCOL					= 0x00000004,
	EFI_OPEN_PROTOCOL_BY_CHILD_CONTROLLER			= 0x00000008,
	EFI_OPEN_PROTOCOL_BY_DRIVER						= 0x00000010,
	EFI_OPEN_PROTOCOL_EXCLUSIVE						= 0x00000020,
};

extern EFI_GUID	EFI_EVENT_GROUP_EXIT_BOOT_SERVICES,		EFI_EVENT_GROUP_VIRTUAL_ADDRESS_CHANGE,		EFI_EVENT_GROUP_MEMORY_MAP_CHANGE,
				EFI_EVENT_GROUP_READY_TO_BOOT,			EFI_HII_PACKAGE_LIST_PROTOCOL_GUID,			EFI_HARDWARE_ERROR_VARIABLE;

EFI_GUID
		EFI_EVENT_GROUP_EXIT_BOOT_SERVICES			= { 0x27abf055, 0xb1b8, 0x4c26, { 0x80, 0x48, 0x74, 0x8f, 0x37, 0xba, 0xa2, 0xdf } },
		EFI_EVENT_GROUP_VIRTUAL_ADDRESS_CHANGE		= { 0x13fa7698, 0xc831, 0x49c7, { 0x87, 0xea, 0x8f, 0x43, 0xfc, 0xc2, 0x51, 0x96 } },
		EFI_EVENT_GROUP_MEMORY_MAP_CHANGE			= { 0x78bee926, 0x692f, 0x48fd, { 0x93, 0xdb, 0x01, 0x42, 0x2e, 0xf0, 0xd7, 0xab } },
		EFI_EVENT_GROUP_READY_TO_BOOT				= { 0x7ce88fb3, 0x4bd7, 0x4679, { 0x87, 0xa8, 0xa8, 0xd8, 0xde, 0xe5, 0x0d, 0x2b } },
		EFI_HII_PACKAGE_LIST_PROTOCOL_GUID			= { 0x6a1ee763, 0xd47a, 0x43b4, { 0xaa, 0xbe, 0xef, 0x1d, 0xe2, 0xab, 0x56, 0xfc } },
		EFI_HARDWARE_ERROR_VARIABLE					= { 0x414e7bdd, 0xe47b, 0x47cc, { 0xb2, 0x44, 0xbb, 0x61, 0x02, 0x0c, 0xf5, 0x16 } };

#endif