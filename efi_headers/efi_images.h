//
//  efi_images.h
//  EFI Test
//
//  Created by Gwynne Raskind on 3/9/14.
//  Copyright (c) 2014 Gwynne Raskind. All rights reserved.
//

#ifndef EFI_efi_images_h
#define EFI_efi_images_h

enum {
	EFI_LOADED_IMAGE_PROTOCOL_REVISION = 0x1000,
};

extern EFI_GUID	EFI_LOADED_IMAGE_PROTOCOL_GUID;

EFI_GUID
		EFI_LOADED_IMAGE_PROTOCOL_GUID				= { 0x5b1b31a1, 0x9562, 0x11d2, { 0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b } };

typedef struct EFI_LOADED_IMAGE_PROTOCOL {
	UINT32						Revision;
	EFI_HANDLE					ParentHandle;
	EFI_SYSTEM_TABLE			*SystemTable;
	EFI_HANDLE					DeviceHandle;
	EFI_DEVICE_PATH_PROTOCOL	*FilePath;
	VOID						*Reserved;
	UINT32						LoadOptionsSize;
	VOID						*LoadOptions;
	VOID						*ImageBase;
	UINT64						ImageSize;
	EFI_MEMORY_TYPE				ImageCodeType;
	EFI_MEMORY_TYPE				ImageDataType;
	EFI_STATUS					(EFIAPI *Unload)(IN EFI_HANDLE ImageHandle);
} EFI_LOADED_IMAGE_PROTOCOL;

#endif
