//
//  efi_graphics.h
//  EFI Test
//
//  Created by Gwynne Raskind on 3/9/14.
//  Copyright (c) 2014 Gwynne Raskind. All rights reserved.
//

#ifndef EFI_efi_graphics_h
#define EFI_efi_graphics_h

#define EFI_TEXT_ATTR(foreground, background)	((foreground) | ((background) << 4))

enum {
	EFI_BLACK										= 0x00,
	EFI_BLUE										= 0x01,
	EFI_GREEN										= 0x02,
	EFI_CYAN										= 0x03,
	EFI_RED											= 0x04,
	EFI_MAGENTA										= 0x05,
	EFI_BROWN										= 0x06,
	EFI_LIGHTGRAY									= 0x07,
	EFI_BRIGHT										= 0x08,
	EFI_DARKGRAY									= 0x08,
	EFI_LIGHTBLUE									= 0x09,
	EFI_LIGHTGREEN									= 0x0A,
	EFI_LIGHTCYAN									= 0x0B,
	EFI_LIGHTRED									= 0x0C,
	EFI_LIGHTMAGENTA								= 0x0D,
	EFI_YELLOW										= 0x0E,
	EFI_WHITE										= 0x0F,
	EFI_BACKGROUND_BLACK							= 0x00,
	EFI_BACKGROUND_BLUE								= 0x10,
	EFI_BACKGROUND_GREEN							= 0x20,
	EFI_BACKGROUND_CYAN								= 0x30,
	EFI_BACKGROUND_RED								= 0x40,
	EFI_BACKGROUND_MAGENTA							= 0x50,
	EFI_BACKGROUND_BROWN							= 0x60,
	EFI_BACKGROUND_LIGHTGRAY						= 0x70,
};

typedef enum { PixelRedGreenBlueReserved8BitPerColor, PixelBlueGreenRedReserved8BitPerColor, PixelBitMask, PixelBltOnly, PixelFormatMax } EFI_GRAPHICS_PIXEL_FORMAT;
typedef enum { EfiBltVideoFill, EfiBltVideoToBltBuffer, EfiBltBufferToVideo, EfiBltVideoToVideo, EfiGraphicsOutputBltOperationMax } EFI_GRAPHICS_OUTPUT_BLT_OPERATION;

typedef struct {
	UINT32						RedMask;
	UINT32						GreenMask;
	UINT32						BlueMask;
	UINT32						ReservedMask;
} EFI_PIXEL_BITMASK;

typedef struct {
	UINT32						Version;
	UINT32						HorizontalResolution;
	UINT32						VerticalResolution;
	EFI_GRAPHICS_PIXEL_FORMAT	PixelFormat;
	EFI_PIXEL_BITMASK			PixelInformation;
	UINT32						PixelsPerScanLine;
} EFI_GRAPHICS_OUTPUT_MODE_INFORMATION;

typedef struct {
	UINT32						MaxMode;
	UINT32						Mode;
	EFI_GRAPHICS_OUTPUT_MODE_INFORMATION	*Info;
	UINTN						SizeOfInfo;
	EFI_PHYSICAL_ADDRESS		FrameBufferBase;
	UINTN						FrameBufferSize;
} EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE;

typedef struct {
	UINT8						Blue;
	UINT8						Green;
	UINT8						Red;
	UINT8						Reserved;
} EFI_GRAPHICS_OUTPUT_BLT_PIXEL;

typedef enum {
  EfiConsoleControlScreenText,
  EfiConsoleControlScreenGraphics,
  EfiConsoleControlScreenMaxValue
} EFI_CONSOLE_CONTROL_SCREEN_MODE;

extern EFI_GUID	EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,			EFI_CONSOLE_CONTROL_PROTOCOL_GUID;

EFI_GUID
		EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID			= { 0x9043a9de, 0x23dc, 0x4a38, { 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a } },
		EFI_CONSOLE_CONTROL_PROTOCOL_GUID			= { 0xf42f7782, 0x012e, 0x4c12, { 0x99, 0x56, 0x49, 0xf9, 0x43, 0x04, 0xf7, 0x21 } };

typedef struct EFI_CONSOLE_CONTROL_PROTOCOL
{
	EFI_STATUS			(EFIAPI *GetMode)(struct EFI_CONSOLE_CONTROL_PROTOCOL *This, EFI_CONSOLE_CONTROL_SCREEN_MODE *Mode, BOOLEAN *gopUgaExists, BOOLEAN *StdInLocked); // 0x0
	EFI_STATUS			(EFIAPI *SetMode)(struct EFI_CONSOLE_CONTROL_PROTOCOL *This, EFI_CONSOLE_CONTROL_SCREEN_MODE Mode); // 0x8
	EFI_STATUS			(EFIAPI *LockStdIn)(struct EFI_CONSOLE_CONTROL_PROTOCOL *This, CHAR16 *Password); // 0x10
} EFI_CONSOLE_CONTROL_PROTOCOL;

typedef struct EFI_GRAPHICS_OUTPUT_PROTOCOL {
	EFI_STATUS			(EFIAPI *QueryMode)(IN struct EFI_GRAPHICS_OUTPUT_PROTOCOL *, IN UINT32, OUT UINTN *, OUT EFI_GRAPHICS_OUTPUT_MODE_INFORMATION **);
	EFI_STATUS			(EFIAPI *SetMode)(IN struct EFI_GRAPHICS_OUTPUT_PROTOCOL *, IN UINT32);
	EFI_STATUS			(EFIAPI *Blt)(IN struct EFI_GRAPHICS_OUTPUT_PROTOCOL *, IN OUT EFI_GRAPHICS_OUTPUT_BLT_PIXEL * OPTIONAL, IN EFI_GRAPHICS_OUTPUT_BLT_OPERATION,
													  IN UINTN, IN UINTN, IN UINTN, IN UINTN, IN UINTN, IN UINTN, IN UINTN OPTIONAL);
	EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE	*Mode;
} EFI_GRAPHICS_OUTPUT_PROTOCOL;

#endif
