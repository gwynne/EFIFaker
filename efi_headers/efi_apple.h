//
//  efi_apple.h
//
//  Created by Gwynne Raskind on 3/9/14.
//  Copyright (c) 2014 Gwynne Raskind. All rights reserved.
//

#ifndef EFI_efi_apple_h
#define EFI_efi_apple_h

typedef void EFI_UGA_PIXEL;

extern EFI_GUID APPLE_DEVICE_CONTROL_PROTOCOL_GUID,		APPLE_IMAGE_CODEC_PROTOCOL_GUID,
 				APPLE_SET_OS_PROTOCOL_GUID,				APPLE_FIRMWARE_PASSWORD_PROTOCOL_GUID,		APPLE_KEY_STATE_PROTOCOL_GUID;

EFI_GUID
		APPLE_IMAGE_CODEC_PROTOCOL_GUID				= { 0x0dfce9f6, 0xc4e3, 0x45ee, { 0xa0, 0x6a, 0xa8, 0x61, 0x3b, 0x98, 0xa5, 0x07 } },
		APPLE_DEVICE_CONTROL_PROTOCOL_GUID			= { 0x8ece08d8, 0xa6d4, 0x430b, { 0xa7, 0xb0, 0x2d, 0xf3, 0x18, 0xe7, 0x88, 0x4a } },
		APPLE_SET_OS_PROTOCOL_GUID					= { 0xc5c5da95, 0x7d5c, 0x45e6, { 0xb2, 0xf1, 0x3f, 0xd5, 0x2b, 0xb1, 0x00, 0x77 } },
		APPLE_FIRMWARE_PASSWORD_PROTOCOL_GUID		= { 0x8ffeeb3a, 0x4c98, 0x4630, { 0x80, 0x3f, 0x74, 0x0f, 0x95, 0x67, 0x09, 0x1d } },
		APPLE_KEY_STATE_PROTOCOL_GUID				= { 0x5b213447, 0x6e73, 0x4901, { 0xa4, 0xf1, 0xb8, 0x64, 0xf3, 0xb7, 0xa1, 0x72 } };

typedef struct
{
	UINT64				Version; // 0x0
	UINTN				FileExt; // 0x8
	EFI_STATUS			(EFIAPI *RecognizeImageData)(VOID *ImageBuffer, UINTN ImageSize); // 0x10
	EFI_STATUS			(EFIAPI *GetImageDims)(VOID* ImageBuffer, UINTN ImageSize, UINTN* ImageWidth, UINTN* ImageHeight); // 0x18
	EFI_STATUS			(EFIAPI *DecodeImageData)(VOID* ImageBuffer, UINTN ImageSize, EFI_UGA_PIXEL **RawImageData, UINTN *RawImageDataSize); // 0x20
} APPLE_IMAGE_CODEC_PROTOCOL;

typedef struct APPLE_DEVICE_CONTROL_PROTOCOL
{
	UINTN						Unknown0;
	EFI_STATUS					(EFIAPI *ConnectDisplay)(VOID);
	UINTN						Unknown2;
	EFI_STATUS					(EFIAPI *ConnectAll)(VOID);
} APPLE_DEVICE_CONTROL_PROTOCOL;

typedef struct APPLE_SET_OS_PROTOCOL {
	UINT64						Version;
	VOID						(EFIAPI *SetOSVersion)(IN CHAR8 *);
	VOID						(EFIAPI *SetOSVendor)(IN CHAR8 *);
} APPLE_SET_OS_PROTOCOL;

typedef struct APPLE_FIRMWARE_PASSWORD_PROTOCOL
{
	UINT64						Signature;
	UINTN						Unknown[3];
	EFI_STATUS					(EFIAPI *Check)(IN struct APPLE_FIRMWARE_PASSWORD_PROTOCOL *, OUT UINTN *);
} APPLE_FIRMWARE_PASSWORD_PROTOCOL;

typedef struct APPLE_KEY_STATE_PROTOCOL
{
	UINT64						Signature;
	EFI_STATUS					(EFIAPI *ReadKeyState)(IN struct APPLE_KEY_STATE_PROTOCOL *, OUT UINT16 *, OUT UINTN *, OUT CHAR16 *);
} APPLE_KEY_STATE_PROTOCOL;

#endif
