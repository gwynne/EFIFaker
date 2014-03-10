//
//  efi_data_hub.h
//  EFI Test
//
//  Created by Gwynne Raskind on 3/9/14.
//  Copyright (c) 2014 Gwynne Raskind. All rights reserved.
//

#ifndef EFI_efi_data_hub_h
#define EFI_efi_data_hub_h

typedef struct {
	UINT16						Version;
	UINT16						HeaderSize;
	UINT32						RecordSize;
	EFI_GUID					DataRecordGuid;
	EFI_GUID					ProducerName;
	UINT64						DataRecordClass;
	EFI_TIME					LogTime;
	UINT64						LogMonotonicCount;
} EFI_DATA_RECORD_HEADER;

typedef struct {
	UINT32							Version;
	UINT32							HeaderSize;
	UINT16							Instance;
	UINT16							SubInstance;
	UINT32							RecordType;
} EFI_SUBCLASS_TYPE1_HEADER;

typedef struct {
	UINT32							DataNameSize;
	UINT32							DataSize;
} EFI_PROPERTY_SUBCLASS_RECORD;

typedef struct {
	EFI_SUBCLASS_TYPE1_HEADER		Header;
	EFI_PROPERTY_SUBCLASS_RECORD	Record;
} EFI_PROPERTY_SUBCLASS_DATA;

#define EFI_DATA_RECORD_HEADER_VERSION	0x0100

#define EFI_DATA_CLASS_DEBUG			0x0000000000000001
#define EFI_DATA_CLASS_ERROR			0x0000000000000002
#define EFI_DATA_CLASS_DATA				0x0000000000000004
#define EFI_DATA_CLASS_PROGRESS_CODE	0x0000000000000008

extern EFI_GUID	EFI_DATA_HUB_PROTOCOL_GUID;

EFI_GUID
		EFI_DATA_HUB_PROTOCOL_GUID					= { 0xae80d021, 0x618e, 0x11d4, { 0xbc, 0xd7, 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 } };

typedef struct EFI_DATA_HUB_PROTOCOL {
	EFI_STATUS					(EFIAPI *LogData)(IN struct EFI_DATA_HUB_PROTOCOL *, IN EFI_GUID *, IN EFI_GUID *, IN UINT64, IN VOID *, IN UINT32);
	EFI_STATUS					(EFIAPI *GetNextDataRecord)(IN struct EFI_DATA_HUB_PROTOCOL *, IN OUT UINT64 *, IN EFI_EVENT * OPTIONAL, OUT EFI_DATA_RECORD_HEADER **);
	EFI_STATUS					(EFIAPI *RegisterFilterDriver)(IN struct EFI_DATA_HUB_PROTOCOL *, IN EFI_EVENT, IN EFI_TPL, IN UINT64, IN EFI_GUID * OPTIONAL);
	EFI_STATUS					(EFIAPI *UnregisterFilterDriver)(IN struct EFI_DATA_HUB_PROTOCOL *, IN EFI_EVENT);
} EFI_DATA_HUB_PROTOCOL;

#endif
