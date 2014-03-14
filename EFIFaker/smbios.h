//
//  smbios.h
//
//  Created by Gwynne Raskind on 3/12/14.
//  Copyright (c) 2014 Elwea Software. All rights reserved.
//

#ifndef smbios_h
#define smbios_h

#ifdef __cplusplus
extern "C" {
#endif

#include "efi_types.h"

typedef struct {
	UINT8 AnchorString[4];
	UINT8 Checksum;
	UINT8 EntryPointSize;
	UINT8 MajorVersion;
	UINT8 MinorVersion;
	UINT16 MaxStructureSize;
	UINT8 EPSRevision;
	UINT8 FormattedArea[5];
	UINT8 IntermediateAnchorString[5];
	UINT8 IntermediateChecksum;
	UINT16 StructureTableSize;
	UINT32 StructureTablePointer; // must be in low 4GB of memory
	UINT16 NumberOfStructures;
	UINT8 BCDRevision;
} __attribute__((packed)) SMBIOSTableEntryPoint;

static const UINT8 smbiosData[] = {
	0x5f, 0x53, 0x4d, 0x5f, 0xab, 0x1f, 0x02, 0x04, 0xd2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x5f, 0x44, 0x4d, 0x49, 0x5f, 0xa7, 0xcd, 0x09, 0x00, 0x40, 0xd1, 0x8c, 0x2a, 0x00, 0x24,
};

//typedef UINT8 SMBStrIdx;
//
//extern NSData *_build_smbios_table(void);
//extern void _fixup_smbios_pointers(VOID *realTablePtr);

#ifdef __cplusplus
};
#endif

#endif
