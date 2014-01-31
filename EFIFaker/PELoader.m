//
//  PELoader.m
//  EFIFaker
//
//  Created by Gwynne Raskind on 1/13/14.
//  Copyright (c) 2014 Elwea Software. All rights reserved.
//

#import "PELoader.h"
#import <mach/vm_map.h>

static void PELog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

void PELog(NSString *format, ...)
{
	va_list args;
	
	va_start(args, format);
//	fprintf(stdout, [[NSString alloc] initWithFormat:format arguments:args].UTF8String);
	va_end(args);
}

static NSError *PEError(int code, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);

NSError *PEError(int code, NSString *format, ...)
{
	va_list args;
	NSString *desc = nil;
	
	va_start(args, format);
	desc = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	return [NSError errorWithDomain:@"PEErrorDomain" code:code userInfo:@{ NSLocalizedDescriptionKey: desc }];
}

#define PEreturn_error(code, format, ...) do { if (error) *error = PEError(code, format, ## __VA_ARGS__); return NO; } while (0)

//------------------------------------------------------------------------------
typedef struct {
	uint32_t Signature;
	uint16_t Machine;
	uint16_t NumberOfSections;
	uint32_t TimeDateStamp;
	uint32_t PointerToSymbolTable;
	uint32_t NumberOfSymbols;
	uint16_t SizeOfOptionalHeader;
	uint16_t Characteristics;
} PEHeader;

typedef struct /*__attribute__((packed))*/ {
	uint16_t Magic;
	uint8_t MajorLinkerVersion;
	uint8_t MinorLinkerVersion;
	uint32_t SizeOfCode;
	uint32_t SizeOfInitializedData;
	uint32_t SizeOfUninitializedData;
	uint32_t AddressOfEntryPoint;
	uint32_t BaseOfCode;
	uint64_t ImageBase;
	uint32_t SectionAlignment;
	uint32_t FileAlignment;
	uint16_t MajorOperatingSystemVersion;
	uint16_t MinorOperatingSystemVersion;
	uint16_t MajorImageVersion;
	uint16_t MinorImageVersion;
	uint16_t MajorSubsystemVersion;
	uint16_t MinorSubsystemVersion;
	uint32_t Win32VersionValue;
	uint32_t SizeOfImage;
	uint32_t SizeOfHeaders;
	uint32_t Checksum;
	uint16_t Subsystem;
	uint16_t DllCharacteristics;
	uint64_t SizeOfStackReserve;
	uint64_t SizeOfStackCommit;
	uint64_t SizeOfHeapReserve;
	uint64_t SizeOfHeapCommit;
	uint32_t LoaderFlags;
	uint32_t NumberOfRvaAndSizes;
} PE32POptionalHeader;

typedef struct {
	uint32_t VirtualAddress;
	uint32_t Size;
} PEDirectoryEntry;

typedef struct {
	char Name[8];
	uint32_t VirtualSize;
	uint32_t VirtualAddress;
	uint32_t SizeOfRawData;
	uint32_t PointerToRawData;
	uint32_t PointerToRelocations;
	uint32_t PointerToLinenumbers;
	uint16_t NumberOfRelocations;
	uint16_t NumberOfLinenumbers;
	uint32_t Characteristics;
} PESectionHeader;

static NSMutableDictionary *machines = nil;
static NSMutableDictionary *characteristics = nil;
static NSMutableDictionary *subsystems = nil;
static NSMutableDictionary *sectCharacteristics = nil;

//------------------------------------------------------------------------------
@interface PELoader ()

@property(nonatomic,assign) PEHeader header;
@property(nonatomic,assign) PE32POptionalHeader optionalHeader;
@property(nonatomic,assign) PESectionHeader *sections;

@property(nonatomic,assign) void *mappedRegion;
@property(nonatomic,assign) size_t regionSize;

@end

@implementation PELoader

- (void)dealloc
{
	if (_sections)
		free(_sections);
	if (_mappedRegion != MAP_FAILED)
		munmap(_mappedRegion, _regionSize);
}

+ (void)initialize
{
	machines = @{
		@(0): @"IMAGE_FILE_MACHINE_UNKNOWN",
		@(0x1d3): @"IMAGE_FILE_MACHINE_AM33",
		@(0x8664): @"IMAGE_FILE_MACHINE_AMD64",
		@(0x1c0): @"IMAGE_FILE_MACHINE_ARM",
		@(0x1c4): @"IMAGE_FILE_MACHINE_ARMNT",
		@(0xaa64): @"IMAGE_FILE_MACHINE_ARM64",
		@(0xebc): @"IMAGE_FILE_MACHINE_EBC",
		@(0x14c): @"IMAGE_FILE_MACHINE_I386",
		@(0x200): @"IMAGE_FILE_MACHINE_IA64",
		@(0x9041): @"IMAGE_FILE_MACHINE_M32R",
		@(0x266): @"IMAGE_FILE_MACHINE_MIPS16",
		@(0x366): @"IMAGE_FILE_MACHINE_MIPSFPU",
		@(0x466): @"IMAGE_FILE_MACHINE_MIPSFPU16",
		@(0x1f0): @"IMAGE_FILE_MACHINE_POWERPC",
		@(0x1f1): @"IMAGE_FILE_MACHINE_POWERPCFP",
		@(0x166): @"IMAGE_FILE_MACHINE_R4000",
		@(0x1a2): @"IMAGE_FILE_MACHINE_SH3",
		@(0x1a3): @"IMAGE_FILE_MACHINE_SH3DSP",
		@(0x1a6): @"IMAGE_FILE_MACHINE_SH4",
		@(0x1a8): @"IMAGE_FILE_MACHINE_SH5",
		@(0x1c2): @"IMAGE_FILE_MACHINE_THUMB",
		@(0x169): @"IMAGE_FILE_MACHINE_WCEMIPSV2",
	}.mutableCopy;

	#define FLAG(dict, name, val) static const uint16_t name = (val); dict[@(val)] = @#name
	characteristics = @{}.mutableCopy;
	FLAG(characteristics, IMAGE_FILE_RELOCS_STRIPPED, 0x0001);
	FLAG(characteristics, IMAGE_FILE_EXECUTABLE_IMAGE, 0x0002);
	FLAG(characteristics, IMAGE_FILE_LINE_NUMS_STRIPPED, 0x0004);
	FLAG(characteristics, IMAGE_FILE_LOCAL_SYMS_STRIPPED, 0x0008);
	FLAG(characteristics, IMAGE_FILE_AGGRESSIVE_WS_TRIM, 0x0010);
	FLAG(characteristics, IMAGE_FILE_LARGE_ADDRESS_AWARE, 0x0020);
	FLAG(characteristics, IMAGE_FILE_RESERVED, 0x0040);
	FLAG(characteristics, IMAGE_FILE_BYTES_REVERSED_LO, 0x0080);
	FLAG(characteristics, IMAGE_FILE_32BIT_MACHINE, 0x0100);
	FLAG(characteristics, IMAGE_FILE_DEBUG_STRIPPED, 0x0200);
	FLAG(characteristics, IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP, 0x0400);
	FLAG(characteristics, IMAGE_FILE_NET_RUN_FROM_SWAP, 0x0800);
	FLAG(characteristics, IMAGE_FILE_SYSTEM, 0x1000);
	FLAG(characteristics, IMAGE_FILE_DLL, 0x2000);
	FLAG(characteristics, IMAGE_FILE_UP_SYSTEM_ONLY, 0x4000);
	FLAG(characteristics, IMAGE_FILE_BYTES_REVERSED_HI, 0x8000);
	
	subsystems = @{}.mutableCopy;
	FLAG(subsystems, IMAGE_SUBSYSTEM_UNKNOWN, 0);
	FLAG(subsystems, IMAGE_SUBSYSTEM_NATIVE, 1);
	FLAG(subsystems, IMAGE_SUBSYSTEM_WINDOWS_GUI, 2);
	FLAG(subsystems, IMAGE_SUBSYSTEM_WINDOWS_CUI, 3);
	FLAG(subsystems, IMAGE_SUBSYSTEM_POSIX_CUI, 7);
	FLAG(subsystems, IMAGE_SUBSYSTEM_WINDOWS_CE_GUI, 9);
	FLAG(subsystems, IMAGE_SUBSYSTEM_EFI_APPLICATION, 10);
	FLAG(subsystems, IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER, 11);
	FLAG(subsystems, IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER, 12);
	FLAG(subsystems, IMAGE_SUBSYSTEM_EFI_ROM, 13);
	FLAG(subsystems, IMAGE_SUBSYSTEM_XBOX, 14);
	
	sectCharacteristics = @{}.mutableCopy;
	FLAG(sectCharacteristics, IMAGE_SCN_TYPE_NO_PAD, 0x00000008);
	FLAG(sectCharacteristics, IMAGE_SCN_CNT_CODE, 0x00000020);
	FLAG(sectCharacteristics, IMAGE_SCN_CNT_INITIALIZED_DATA, 0x00000040);
	FLAG(sectCharacteristics, IMAGE_SCN_CNT_UNINITIALIZED_DATA, 0x00000080);
	FLAG(sectCharacteristics, IMAGE_SCN_LNK_OTHER, 0x00000100);
	FLAG(sectCharacteristics, IMAGE_SCN_LNK_INFO, 0x00000200);
	FLAG(sectCharacteristics, IMAGE_SCN_LNK_REMOVE, 0x00000800);
	FLAG(sectCharacteristics, IMAGE_SCN_LNK_COMDAT, 0x00001000);
	FLAG(sectCharacteristics, IMAGE_SCN_GPREL, 0x00008000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_16BIT, 0x00020000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_LOCKED, 0x00040000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_PRELOAD, 0x00080000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_1BYTES, 0x00100000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_2BYTES, 0x00200000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_4BYTES, 0x00300000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_8BYTES, 0x00400000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_16BYTES, 0x00500000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_32BYTES, 0x00600000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_64BYTES, 0x00700000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_128BYTES, 0x00800000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_256BYTES, 0x00900000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_512BYTES, 0x00a00000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_1024BYTES, 0x00b00000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_2048BYTES, 0x00c00000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_4096BYTES, 0x00d00000);
	FLAG(sectCharacteristics, IMAGE_SCN_ALIGN_8192BYTES, 0x00e00000);
	FLAG(sectCharacteristics, IMAGE_SCN_LNK_NRELOC_OVFL, 0x01000000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_DISCARDABLE, 0x02000000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_NOT_CACHED, 0x04000000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_NOT_PAGED, 0x08000000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_SHARED, 0x10000000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_EXECUTE, 0x20000000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_READ, 0x40000000);
	FLAG(sectCharacteristics, IMAGE_SCN_MEM_WRITE, 0x80000000);
	#undef FLAG
}

- (instancetype)initWithURL:(NSURL *)url error:(NSError * __autoreleasing *)error
{
	if ((self = [super init])) {
		_url = url;
		_mappedRegion = MAP_FAILED;
		_rawContents = [NSData dataWithContentsOfURL:url options:0 error:error];
		if (!_rawContents)
			return nil;
		
		if (![self parseAndReturnError:error])
			return nil;
	}
	return self;
}

- (BOOL)parseAndReturnError:(NSError * __autoreleasing *)error
{
	const uint8_t *p = self.rawContents.bytes;
	
	uint32_t fileStartOffset = *(uint32_t *)(p + 0x3c);
	
	PELog(@"File starts at 0x%08x\n", fileStartOffset);
	
	_header = *(PEHeader *)(p += fileStartOffset);

	time_t t = _header.TimeDateStamp;
	char *ts = ctime(&t);

	if (_header.Signature != 0x00004550) // PE\0\0
		PEreturn_error(1, @"Invalid signature 0x%08x", _header.Signature);
	
	PELog(@"Header:\n");
	PELog(@"\tSignature: 0x%08x\n", _header.Signature);
	PELog(@"\tMachine: %@ (%u)\n", machines[@(_header.Machine)] ?: @"(????)", _header.Machine);
	PELog(@"\tSection count: %hu\n", _header.NumberOfSections);
	PELog(@"\tTimestamp: %@\n", ts ? [[NSString stringWithUTF8String:ts] substringToIndex:24] : @(_header.TimeDateStamp));
	PELog(@"\tOptional header size: %hu\n", _header.SizeOfOptionalHeader);
	PELog(@"\tCharacteristics: ");
	for (uint16_t v = 0; v < 16; ++v) {
		if ((_header.Characteristics & (1 << v)) != 0)
			PELog(@"%@ ", characteristics[@(1 << v)]);
	}
	PELog(@"\n");
	
	if (!_header.SizeOfOptionalHeader) {
		PELog(@"WARNING: No optional header??\n");
		return YES;
	}
	
	_optionalHeader = *(PE32POptionalHeader *)(p += sizeof(PEHeader));
	
	PELog(@"Optional header:\n");
	PELog(@"\tMagic: %04x\n", _optionalHeader.Magic);
	if (_optionalHeader.Magic != 0x020b)
		PEreturn_error(2, @"File is not PE32+");
	PELog(@"\tLinker version: %hhu.%hhu\n", _optionalHeader.MajorLinkerVersion, _optionalHeader.MinorLinkerVersion);
	PELog(@"\tCode size: %u bytes\n", _optionalHeader.SizeOfCode);
	PELog(@"\tInitialized data size: %u bytes\n", _optionalHeader.SizeOfInitializedData);
	PELog(@"\tUninitialized data size: %u bytes\n", _optionalHeader.SizeOfUninitializedData);
	PELog(@"\tEntry point address: 0x%08x\n", _optionalHeader.AddressOfEntryPoint);
	PELog(@"\tCode base: 0x%08x\n", _optionalHeader.BaseOfCode);
	PELog(@"\tImage base: 0x%016llx\n", _optionalHeader.ImageBase);
	PELog(@"\tSection alignment: %u\n", _optionalHeader.SectionAlignment);
	PELog(@"\tFile alignment: %u\n", _optionalHeader.FileAlignment);
	PELog(@"\tOS version: %hu.%hu\n", _optionalHeader.MajorOperatingSystemVersion, _optionalHeader.MinorOperatingSystemVersion);
	PELog(@"\tImage version: %hu.%hu\n", _optionalHeader.MajorImageVersion, _optionalHeader.MinorImageVersion);
	PELog(@"\tSubsystem version: %hu.%hu\n", _optionalHeader.MajorSubsystemVersion, _optionalHeader.MinorSubsystemVersion);
	PELog(@"\tWin32 version: %u\n", _optionalHeader.Win32VersionValue);
	PELog(@"\tImage size: %u bytes\n", _optionalHeader.SizeOfImage);
	PELog(@"\tHeaders size: %u bytes\n", _optionalHeader.SizeOfHeaders);
	PELog(@"\tChecksum: 0x%08x\n", _optionalHeader.Checksum);
	PELog(@"\tSubsystem: %@ (%hu)\n", subsystems[@(_optionalHeader.Subsystem)] ?: @"(????)", _optionalHeader.Subsystem);
	PELog(@"\tDLL characteristics: 0x%04hx\n", _optionalHeader.DllCharacteristics);
	PELog(@"\tStack reserve/commit: %llu/%llu bytes\n", _optionalHeader.SizeOfStackReserve, _optionalHeader.SizeOfStackCommit);
	PELog(@"\tHeap reserve/commit: %llu/%llu bytes\n", _optionalHeader.SizeOfHeapReserve, _optionalHeader.SizeOfHeapCommit);
	PELog(@"\tLoader flags: 0x%08x\n", _optionalHeader.LoaderFlags);
	PELog(@"\tRVA count: %u\n", _optionalHeader.NumberOfRvaAndSizes);
	p += sizeof(PE32POptionalHeader) - sizeof(PEDirectoryEntry);
	#define DirectoryEntry(n, name, uname) do {	\
		if (_optionalHeader.NumberOfRvaAndSizes > (n)) {	\
			PEDirectoryEntry name = *(PEDirectoryEntry *)(p += sizeof(PEDirectoryEntry));	\
			if (name.VirtualAddress) {	\
				PELog(@#uname @" @ 0x%016llx (Base + 0x%08x) - %u bytes\n", name.VirtualAddress + _optionalHeader.ImageBase,	\
					  name.VirtualAddress, name.Size);	\
			}	\
		}	\
	} while (0)
	DirectoryEntry(0, exportTable, Export Table);
	DirectoryEntry(1, importTable, Import Table);
	DirectoryEntry(2, resourceTable, Resource Table);
	DirectoryEntry(3, exceptionTable, Exception Table);
	DirectoryEntry(4, certificateTable, Certificate Table);
	DirectoryEntry(5, baseRelocationTable, Base Relocation Table);
	DirectoryEntry(6, debug, Debug);
	DirectoryEntry(7, architecture, Architecture);
	DirectoryEntry(8, globalPtr, Global Pointer);
	DirectoryEntry(9, tlsTable, TLS Table);
	DirectoryEntry(10, loadConfigTable, Load Config Table);
	DirectoryEntry(11, boundImportTable, Bound Import Table);
	DirectoryEntry(12, iat, IAT);
	DirectoryEntry(13, delayImportDescriptor, Delay Import Descriptor);
	DirectoryEntry(14, clrRuntimeHeader, CLR Runtime Header);
	DirectoryEntry(15, reserved, Reserved);
	p += sizeof(PEDirectoryEntry);
	
	_sections = calloc(_header.NumberOfSections, sizeof(PESectionHeader));
	memcpy(_sections, p, sizeof(PESectionHeader) * _header.NumberOfSections);
	
	for (uint32_t sect = 0; sect < _header.NumberOfSections; ++sect, p += sizeof(PESectionHeader)) {
		PESectionHeader section = _sections[sect];
		
		PELog(@"Section %.8s (%u):\n", section.Name, sect);
		PELog(@"\tVirtual size: %u (0x%08x) bytes\n", section.VirtualSize, section.VirtualSize);
		PELog(@"\tVirtual address: 0x%08x\n", section.VirtualAddress);
		PELog(@"\tRaw data size: %u bytes\n", section.SizeOfRawData);
		PELog(@"\tRaw data pointer: 0x%08x\n", section.PointerToRawData);
		PELog(@"\tRelocations pointer: 0x%08x\n", section.PointerToRelocations);
		PELog(@"\tLine numbers pointer: 0x%08x\n", section.PointerToLinenumbers);
		PELog(@"\tNumber of relocations: %hu\n", section.NumberOfRelocations);
		PELog(@"\tLine number count: %hu\n", section.NumberOfLinenumbers);
		PELog(@"\tCharacteristics: 0x%08x\n", section.Characteristics);
	}
	return YES;
}

- (BOOL)mapAndReturnError:(NSError * __autoreleasing *)error
{
//	if (munmap((void *)0x1000, 0x100000000) < 0) {
//		if (error) {
//			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
//		}
//		return NO;
//	}
//	_mappedRegion = mmap(_optionalHeader.ImageBase, _optionalHeader.SizeOfImage, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_FIXED | MAP_PRIVATE, -1, 0);
//	if (_mappedRegion == MAP_FAILED) {
//		if (error) {
//			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
//		}
//		return NO;
//	}
//	_regionSize = _optionalHeader.SizeOfImage;
//	
//	for (uint32_t sect = 0; sect < _header.NumberOfSections; ++sect) {
//		memcpy((uint8_t *)_mappedRegion + _sections[sect].VirtualAddress, (const uint8_t *)_rawContents.bytes + _sections[sect].PointerToRawData,
//			  _sections[sect].SizeOfRawData);
//	}
	_entryPoint = _optionalHeader.AddressOfEntryPoint;
	return YES;
}

@end
