//
//  efi_types.h
//
//  Created by Gwynne Raskind on 3/9/14.
//  Copyright (c) 2014 Gwynne Raskind. All rights reserved.
//

#ifndef EFI_efi_types_h
#define EFI_efi_types_h

typedef unsigned char BOOLEAN;

typedef __INT64_TYPE__ INTN;
#ifdef __UINT64_TYPE__
typedef __UINT64_TYPE__ UINTN;
#else
typedef unsigned __INT64_TYPE__ UINTN;
#endif

typedef __INT8_TYPE__ INT8;
#ifdef __UINT8_TYPE__
typedef __UINT8_TYPE__ UINT8;
#else
typedef unsigned __INT8_TYPE__ UINT8;
#endif

typedef __INT16_TYPE__ INT16;
#ifdef __UINT16_TYPE__
typedef __UINT16_TYPE__ UINT16;
#else
typedef unsigned __INT16_TYPE__ UINT16;
#endif

typedef __INT32_TYPE__ INT32;
#ifdef __UINT32_TYPE__
typedef __UINT32_TYPE__ UINT32;
#else
typedef unsigned __INT32_TYPE__ UINT32;
#endif

typedef __INT64_TYPE__ INT64;
#ifdef __UINT64_TYPE__
typedef __UINT64_TYPE__ UINT64;
#else
typedef unsigned __INT64_TYPE__ UINT64;
#endif

typedef INT8 CHAR8;
typedef UINT16 CHAR16;
typedef void VOID;

typedef struct { UINT32 guid1; UINT16 guid2, guid3; UINT8 guid4[8]; } EFI_GUID;
typedef UINTN EFI_STATUS;
typedef VOID *EFI_HANDLE;
typedef VOID *EFI_EVENT;
typedef UINT64 EFI_LBA;
typedef UINTN EFI_TPL;
typedef UINT8 EFI_MAC_ADDRESS[32];
typedef UINT8 EFI_IPv4_ADDRESS[4];
typedef UINT8 EFI_IPv6_ADDRESS[16];
typedef UINT8 EFI_IP_ADDRESS[16];

typedef UINT64 EFI_PHYSICAL_ADDRESS;
typedef UINT64 EFI_VIRTUAL_ADDRESS;
typedef UINT8 EFI_KEY_TOGGLE_STATE;

#define IN
#define OUT
#define OPTIONAL
#define CONST

#if defined(__gcc__) && __gcc__
#define EFIAPI __attribute__((ms_abi))
#else
#define EFIAPI
#endif

enum/* : uint64_t*/ {
	EFI_ERROR_FLAG = 0x8000000000000000,
	EFI_SUCCESS = 0,
	EFI_LOAD_ERROR = 1 | EFI_ERROR_FLAG,
	EFI_INVALID_PARAMETER = 2 | EFI_ERROR_FLAG,
	EFI_UNSUPPORTED = 3 | EFI_ERROR_FLAG,
	EFI_BAD_BUFFER_SIZE = 4 | EFI_ERROR_FLAG,
	EFI_BUFFER_TOO_SMALL = 5 | EFI_ERROR_FLAG,
	EFI_NOT_READY = 6 | EFI_ERROR_FLAG,
	EFI_DEVICE_ERROR = 7 | EFI_ERROR_FLAG,
	EFI_WRITE_PROTECTED = 8 | EFI_ERROR_FLAG,
	EFI_OUT_OF_RESOURCES = 9 | EFI_ERROR_FLAG,
	EFI_VOLUME_CORRUPTED = 10 | EFI_ERROR_FLAG,
	EFI_VOLUME_FULL = 11 | EFI_ERROR_FLAG,
	EFI_NO_MEDIA = 12 | EFI_ERROR_FLAG,
	EFI_MEDIA_CHANGED = 13 | EFI_ERROR_FLAG,
	EFI_NOT_FOUND = 14 | EFI_ERROR_FLAG,
	EFI_ACCESS_DENIED = 15 | EFI_ERROR_FLAG,
	EFI_NO_RESPONSE = 16 | EFI_ERROR_FLAG,
	EFI_NO_MAPPING = 17 | EFI_ERROR_FLAG,
	EFI_TIMEOUT = 18 | EFI_ERROR_FLAG,
	EFI_NOT_STARTED = 19 | EFI_ERROR_FLAG,
	EFI_ALREADY_STARTED = 20 | EFI_ERROR_FLAG,
	EFI_ABORTED = 21 | EFI_ERROR_FLAG,
	EFI_ICMP_ERROR = 22 | EFI_ERROR_FLAG,
	EFI_TFTP_ERROR = 23 | EFI_ERROR_FLAG,
	EFI_PROTOCOL_ERROR = 24 | EFI_ERROR_FLAG,
	EFI_INCOMPATIBLE_VERSION = 25 | EFI_ERROR_FLAG,
	EFI_SECURITY_VIOLATION = 26 | EFI_ERROR_FLAG,
	EFI_CRC_ERROR = 27 | EFI_ERROR_FLAG,
	EFI_END_OF_MEDIA = 28 | EFI_ERROR_FLAG,
	EFI_END_OF_FILE = 29 | EFI_ERROR_FLAG,
	EFI_INVALID_LANGUAGE = 30 | EFI_ERROR_FLAG,
	EFI_COMPROMISED_DATA = 31 | EFI_ERROR_FLAG,
	EFI_WARN_UNKNOWN_GLYPH = 1,
	EFI_WARN_DELETE_FAILURE,
	EFI_WARN_WRITE_FAILURE,
	EFI_WARN_BUFFER_TOO_SMALL,
	EFI_WARN_STALE_DATA,
};

typedef struct {
	UINT16						ScanCode;
	CHAR16						UnicodeChar;
} EFI_INPUT_KEY;

typedef struct {
	UINT32						KeyShiftState;
	EFI_KEY_TOGGLE_STATE		KeyToggleState;
	UINT8						__Padding[3];
} EFI_KEY_STATE;

typedef struct {
	EFI_INPUT_KEY				Key;
	EFI_KEY_STATE				KeyState;
} EFI_KEY_DATA;

typedef struct {
	UINT16						Year;
	UINT8						Month;
	UINT8						Day;
	UINT8						Hour;
	UINT8						Minute;
	UINT8						Second;
	UINT8						Pad1;
	UINT32						Nanosecond;
	INT16						TimeZone;
	UINT8						Daylight;
	UINT8						Pad2;
} EFI_TIME;

#endif
