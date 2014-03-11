//
//  main.m
//  EFIFaker
//
//  Created by Gwynne Raskind on 1/13/14.
//  Copyright (c) 2014 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/ioctl.h>
#import <sys/stat.h>
#import <sys/mount.h>
#import <sys/param.h>
#import <setjmp.h>
#import "PELoader.h"
#import "efi_tables.h"
#import "blockimp.h"

static void __attribute__((naked,used,noinline)) __hack_debug_logs(void);
static void __attribute__((naked,used,noinline)) __hack_jumper(void);
static void __attribute__((naked,used,noinline)) __hack_debug_region(void);

typedef struct { uint64_t rax, rdx; } msr_result;

static msr_result deal_with_msr(uint32_t which);

static void *shim(id block)
{
	return pl_imp_implementationWithBlock((__bridge void *)block);
}

static uint32_t crc32(uint8_t *p, size_t len)
{
	uint32_t crc = 0xffffffff;
	
	for (size_t n = 0; n < len; ++n) {
		crc = ((crc >> 8) & 0x00ffffff) ^ crc32tab[(crc ^ p[n]) & 0xff];
	}
	return crc;
}

static const char *guid_str(EFI_GUID *guid)
{
	static char buf[128];
	
	snprintf(buf, 128, "{ 0x%08x, 0x%04hx, 0x%04hx, { 0x%02hhx, 0x%02hhx, 0x%02hhx, 0x%02hhx, 0x%02hhx, 0x%02hhx, 0x%02hhx, 0x%02hhx } }",
			 guid->guid1, guid->guid2, guid->guid3, guid->guid4[0], guid->guid4[1], guid->guid4[2], guid->guid4[3],
			 guid->guid4[4], guid->guid4[5], guid->guid4[6], guid->guid4[7]);
	return strdup(buf);
}

static NSUInteger wstrlen(CHAR16 *s)
{
	NSUInteger l = 0;
	
	while (*s++) ++l;
	return l;
}

static const char *utf8_str(CHAR16 *utf16_str)
{
	return [NSString stringWithCharacters:utf16_str length:wstrlen(utf16_str)].UTF8String;
}

static EFI_TIME efi_time_from_timespec(struct timespec ts)
{
	struct tm notEfiTime = {0};
	EFI_TIME efiTime = {0};
	
	gmtime_r(&ts.tv_sec, &notEfiTime);
	efiTime.Year = notEfiTime.tm_year;
	efiTime.Month = notEfiTime.tm_mon;
	efiTime.Day = notEfiTime.tm_mday;
	efiTime.Hour = notEfiTime.tm_hour;
	efiTime.Minute = notEfiTime.tm_min;
	efiTime.Second = notEfiTime.tm_sec;
	efiTime.Pad1 = 0;
	efiTime.Nanosecond = ts.tv_nsec;
	efiTime.TimeZone = notEfiTime.tm_gmtoff;
	efiTime.Daylight = (notEfiTime.tm_isdst ? EFI_TIME_IN_DAYLIGHT : 0) | EFI_TIME_ADJUST_DAYLIGHT;
	efiTime.Pad2 = 0;
	return efiTime;
}

#define EfiLog(format, ...) fprintf(stderr, format, ## __VA_ARGS__)

typedef struct {
	EFI_DATA_HUB_PROTOCOL Hub;
	NSMutableArray * __unsafe_unretained dataRecords;
	NSUInteger iteration;
} EFI_DATA_HUB_PROTOCOL_INTERNAL;
static EFI_STATUS noshim_LogData(EFI_DATA_HUB_PROTOCOL_INTERNAL *This, EFI_GUID *DataRecordGuid, EFI_GUID *ProducerName, UINT64 DataRecordClass,
								 VOID *RawData, UINT32 RawDataSize)
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	struct timespec ts = { .tv_sec = tv.tv_sec, .tv_nsec = tv.tv_usec * NSEC_PER_USEC };
	EFI_DATA_RECORD_HEADER header = {
		.Version = EFI_DATA_RECORD_HEADER_VERSION,
		.HeaderSize = sizeof(EFI_DATA_RECORD_HEADER),
		.RecordSize = RawDataSize + sizeof(EFI_DATA_RECORD_HEADER),
		.DataRecordGuid = *DataRecordGuid,
		.ProducerName = *ProducerName,
		.DataRecordClass = DataRecordClass,
		.LogTime = efi_time_from_timespec(ts),
		.LogMonotonicCount = [NSDate timeIntervalSinceReferenceDate] * (double)NSEC_PER_SEC,
	};
	
	EfiLog("--> EfiDataHub.LogData(%s, %s, %llu, %u)\n", guid_str(DataRecordGuid), guid_str(ProducerName), DataRecordClass, RawDataSize);
	NSMutableData *data = [NSMutableData dataWithBytes:&header length:sizeof(header)];
	
	[data appendBytes:RawData length:RawDataSize];
	[This->dataRecords addObject:data];
	return EFI_SUCCESS;
}

void setprop(EFI_DATA_HUB_PROTOCOL *hubProtocol, CHAR16 *name, EFI_GUID guid, VOID *data, UINT32 dataLen)
{
	static EFI_GUID specialGuid = { 0x64517cc8, 0x6561, 0x4051, { 0xb0, 0x3c, 0x59, 0x64, 0xb6, 0x0f, 0x4c, 0x7a } };
	size_t nameLen = (wstrlen(name) + 1) * sizeof(CHAR16);
	size_t dlen = sizeof(EFI_PROPERTY_SUBCLASS_DATA) + nameLen + dataLen;
	EFI_PROPERTY_SUBCLASS_DATA *dataRec = calloc(1, sizeof(EFI_PROPERTY_SUBCLASS_DATA) + nameLen + dataLen);
	
	dataRec->Header.Version = EFI_DATA_RECORD_HEADER_VERSION;
	dataRec->Header.HeaderSize = sizeof(EFI_SUBCLASS_TYPE1_HEADER);
	dataRec->Header.Instance = 0xffff;
	dataRec->Header.SubInstance = 0xffff;
	dataRec->Header.RecordType = 0xffffffff;
	dataRec->Record.DataNameSize = nameLen;
	dataRec->Record.DataSize = dataLen;
	memcpy(((char *)dataRec) + sizeof(EFI_PROPERTY_SUBCLASS_DATA), name, nameLen);
	memcpy(((char *)dataRec) + sizeof(EFI_PROPERTY_SUBCLASS_DATA) + nameLen, data, dataLen);
	noshim_LogData((EFI_DATA_HUB_PROTOCOL_INTERNAL *)hubProtocol, &guid, &specialGuid, EFI_DATA_CLASS_DATA, dataRec, dlen);
	free(dataRec);
}

#undef memcpy
#undef memmove
#undef memset
static jmp_buf jb;
static EFI_STATUS __attribute__((noinline)) callEntryPoint(PELoader *loader)
{
	NSMutableDictionary *efiVars = @{
		@"{ 0x7c436110, 0xab2a, 0x4bbb, { 0xa8, 0x80, 0xfe, 0x41, 0x99, 0x5c, 0x9f, 0x82 } }.boot-args": [@"-v" dataUsingEncoding:NSUTF16LittleEndianStringEncoding],
//		@"{ 0x4d1ede05, 0x38c7, 0x4a6a, { 0x9c, 0xc6, 0x4b, 0xcc, 0xa8, 0xb3, 0x8c, 0x14 } }.ROM": [NSData dataWithBytes:(char[]){ 0x56, 0x4d, 0x7f, 0xa2, 0xf8, 0x2c } length:6],
//		@"{ 0x4d1ede05, 0x38c7, 0x4a6a, { 0x9c, 0xc6, 0x4b, 0xcc, 0xa8, 0xb3, 0x8c, 0x14 } }.MLB": [NSData dataWithBytes:(char[]){ 0x61, 0x66, 0x4f, 0x49, 0x6e, 0x61, 0x68, 0x4a, 0x69, 0x75, 0x4d, 0x38, 0x49, 0x41, 0x2e, 0x2e, 0x2e } length:17],
//		@"{ 0x7c436110, 0xab2a, 0x4bbb, { 0xa8, 0x80, 0xfe, 0x41, 0x99, 0x5c, 0x9f, 0x82 } }.efiboot-perf-record": [NSData dataWithBytes:(int[1]){1} length:1],
	}.mutableCopy;
	EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL outputProtocol = {
		.Reset = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, BOOLEAN ExtendedVerification) {
			return EFI_SUCCESS;
		}),
		.OutputString = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, CHAR16 *String) {
			printf("%s", [NSString stringWithCharacters:String length:wstrlen(String)].UTF8String);
			return EFI_SUCCESS;
		}),
		.TestString = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, CHAR16 *String) {
			return EFI_SUCCESS;
		}),
		.QueryMode = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, UINTN ModeNumber, UINTN *Columns, UINTN *Rows) {
			if (ModeNumber == 0) {
				*Columns = 80;
				*Rows = 25;
			} else if (ModeNumber == 1) {
				return EFI_UNSUPPORTED;
			} else if (ModeNumber == 2) {
				if (isatty(STDOUT_FILENO)) {
					struct winsize ws;
					
					if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) < 0)
						return EFI_DEVICE_ERROR;
					*Columns = ws.ws_col;
					*Rows = ws.ws_row;
				} else {
					*Columns = 80;
					*Rows = 25;
				}
			}
			return EFI_SUCCESS;
		}),
		.SetMode = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, UINTN ModeNumber) {
			if (ModeNumber == 0 || ModeNumber == 2)
				return EFI_SUCCESS;
			else
				return EFI_UNSUPPORTED;
		}),
		.SetAttribute = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, UINTN Attribute) {
			char colors[16] = { [EFI_BLACK] = 30, [EFI_BLUE] = 34, [EFI_GREEN] = 32, [EFI_CYAN] = 36, [EFI_RED] = 31, [EFI_MAGENTA] = 35,
								[EFI_BROWN] = 33, [EFI_LIGHTGRAY] = 37, [EFI_DARKGRAY] = 90, [EFI_LIGHTBLUE] = 94, [EFI_LIGHTGREEN] = 92,
								[EFI_LIGHTCYAN] = 96, [EFI_LIGHTRED] = 91, [EFI_LIGHTMAGENTA] = 95, [EFI_YELLOW] = 93, [EFI_WHITE] = 97 };
			int fg = colors[(Attribute & 0x0f)], bg = colors[(Attribute & 0xf0)];
			BOOLEAN intense = false;
			
			if (fg > 37) {
				intense = true;
				fg -= 60;
			}
			printf("\033[%d;%d;%dm", intense ? 1 : 0, fg, bg + 10);
			return EFI_SUCCESS;
		}),
		.ClearScreen = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This) {
			printf("\033[2J");
			return EFI_SUCCESS;
		}),
		.SetCursorPosition = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, UINTN Column, UINTN Row) {
			printf("\033[%llu;%lluH", Row, Column);
			return EFI_SUCCESS;
		}),
		.EnableCursor = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This, BOOLEAN Visible) {
			return EFI_UNSUPPORTED;
		}),
		.Mode = (SIMPLE_TEXT_OUTPUT_MODE [1]){{ .MaxMode = 2, .Mode = 0, .Attribute = 0x0, .CursorColumn = 1, .CursorRow = 1, .CursorVisible = TRUE }},
	};
	EFI_SIMPLE_TEXT_INPUT_PROTOCOL inputProtocol = {
		.Reset = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_INPUT_PROTOCOL *This, BOOLEAN ExtendedVerification) {
			return EFI_SUCCESS;
		}),
		.ReadKeyStroke = shim(^ EFI_STATUS (EFI_SIMPLE_TEXT_INPUT_PROTOCOL *This, EFI_INPUT_KEY *Key) {
			CHAR16 c = fgetc(stdin);
			
			if (c) {
				Key->UnicodeChar = c;
			} else {
				Key->ScanCode = c;
			}
			return EFI_SUCCESS;
		}),
		.WaitForKey = NULL
	};
	EFI_CONSOLE_CONTROL_PROTOCOL consoleControlProtocol = {
		.GetMode = shim(^ EFI_STATUS (EFI_CONSOLE_CONTROL_PROTOCOL *This, EFI_CONSOLE_CONTROL_SCREEN_MODE *Mode, BOOLEAN *GopUgaExists, BOOLEAN *StdInLocked) {
			EfiLog("--> EfiConsoleControl.GetMode()\n");
			*Mode = EfiConsoleControlScreenText;
			*GopUgaExists = false;
			*StdInLocked = false;
			return EFI_SUCCESS;
		}),
		.SetMode = shim(^ EFI_STATUS (EFI_CONSOLE_CONTROL_PROTOCOL *This, EFI_CONSOLE_CONTROL_SCREEN_MODE Mode) {
			EfiLog("--> EfiConsoleControl.SetMode(%d)\n", Mode);
			return (Mode == EfiConsoleControlScreenText || Mode == EfiConsoleControlScreenGraphics) ? EFI_SUCCESS : EFI_UNSUPPORTED;
		}),
		.LockStdIn = shim(^ EFI_STATUS (EFI_CONSOLE_CONTROL_PROTOCOL *This, CHAR16 *Password) {
			EfiLog("--> EfiConsoleControl.LockStdIn(%s)\n", utf8_str(Password));
			return EFI_UNSUPPORTED;
		}),
	};
	typedef struct {
		EFI_DEVICE_PATH_PROTOCOL Hdr;
		EFI_GUID VendorGuid;
		EFI_DEVICE_PATH_PROTOCOL EndNode;
	} EFI_DEVICE_PATH_PROTOCOL_VENDOR;
	EFI_DEVICE_PATH_PROTOCOL_VENDOR devicePathProtocol = {
		.Hdr = { .Type = 1, .SubType = 4, .Length = 20, },
		.VendorGuid = { 0x01234567, 0x89ab, 0xcdef, { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff } },
		.EndNode = { .Type = 0x7f, .SubType = 0xff, .Length = 4 },
	};
	EFI_LOADED_IMAGE_PROTOCOL loadedImageProtocol = {
		.Revision = EFI_LOADED_IMAGE_PROTOCOL_REVISION,
		.ParentHandle = NULL,
		.SystemTable = NULL,
		.DeviceHandle = 0xabad1deadeadbee1,
		.FilePath = (EFI_DEVICE_PATH_PROTOCOL *)&devicePathProtocol,
		.Reserved = NULL,
		.LoadOptionsSize = 0,
		.LoadOptions = NULL,
		.ImageBase = NULL,
		.ImageSize = 0x7d0000,
		.ImageCodeType = EfiLoaderCode,
		.ImageDataType = EfiLoaderData,
		.Unload = shim(^ EFI_STATUS (EFI_HANDLE ImageHandle) {
			EfiLog("--> EFILoadedImageProtocol.Unload(%p)\n", ImageHandle);
			return EFI_UNSUPPORTED;
		}),
	};
	typedef struct {
		EFI_FILE_PROTOCOL File;
		int fd;
		NSString * __unsafe_unretained path;
	} EFI_FILE_PROTOCOL_INTERNAL;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	EFI_FILE_PROTOCOL_INTERNAL rootFileProtocol = { .File = {
		.Revision = EFI_FILE_PROTOCOL_REVISION,
		.Open = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This, EFI_FILE_PROTOCOL **NewHandle, CHAR16 *FileName, UINT64 OpenMode, UINT64 Attributes) {
			NSString *fullPath = [This->path stringByAppendingFormat:@"\\%@", [NSString stringWithCharacters:FileName length:wstrlen(FileName)]];
			
			fullPath = [fullPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
			EfiLog("--> EfiFileProtocol.Open(%s, %llu, %llx)\n", fullPath.UTF8String, OpenMode, Attributes);
			if (![fileManager fileExistsAtPath:fullPath]) {
				return EFI_NOT_FOUND;
			}
			
			int mode = ((OpenMode & EFI_FILE_MODE_READ) && (OpenMode & EFI_FILE_MODE_WRITE) ? O_RDWR :
					   ((OpenMode & EFI_FILE_MODE_READ) ? O_RDONLY : (OpenMode & EFI_FILE_MODE_WRITE) ? O_WRONLY : 0)) |
					   ((OpenMode & EFI_FILE_MODE_CREATE ? O_CREAT : 0));
			int fd = open(fullPath.UTF8String, mode, S_IRUSR | S_IRGRP | S_IROTH | ((Attributes & EFI_FILE_READ_ONLY) ? 0 : S_IWUSR | S_IWGRP | S_IWOTH));
			
			if (fd == -1) {
				return (errno == EPERM ? EFI_ACCESS_DENIED : (errno == ENOSPC ? EFI_VOLUME_FULL : EFI_DEVICE_ERROR));
			}

			EFI_FILE_PROTOCOL_INTERNAL *handle = calloc(sizeof(EFI_FILE_PROTOCOL_INTERNAL), 1);
			
			memcpy(handle, This, sizeof(EFI_FILE_PROTOCOL_INTERNAL));
			handle->path = (__bridge NSString *)(__bridge_retained CFStringRef)fullPath;
			handle->fd = fd;
			*NewHandle = (EFI_FILE_PROTOCOL *)handle;
			return EFI_SUCCESS;
		}),
		.Close = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This) {
			EfiLog("--> EfiFileProtocol.Close(%s)\n", This->path.UTF8String);
			if (This->fd != -1) {
				close(This->fd);
			}
			if (This->path) {
				CFRelease((__bridge CFStringRef)This->path);
			}
			free(This);
			return EFI_SUCCESS;
		}),
		.Delete = shim(^ EFI_STATUS	(EFI_FILE_PROTOCOL_INTERNAL *This) {
			EfiLog("--> EfiFileProtocol.Delete(%s)\n", This->path.UTF8String);
			return EFI_UNSUPPORTED;
		}),
		.Read = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This, UINTN *BufferSize, VOID *Buffer) {
			EfiLog("--> EfiFileProtocol.Read(%s, %llu)\n", This->path.UTF8String, *BufferSize);
			if (This->fd != -1) {
				int r = read(This->fd, Buffer, *BufferSize);
				
				if (r >= 0) {
					*BufferSize = r;
					return EFI_SUCCESS;
				}
				return EFI_DEVICE_ERROR;
			}
			return EFI_INVALID_PARAMETER;
		}),
		.Write = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This, UINTN *BufferSize, VOID *Buffer) {
			EfiLog("--> EfiFileProtocol.Write(%s, %llu)\n", This->path.UTF8String, *BufferSize);
			return EFI_UNSUPPORTED;
		}),
		.SetPosition = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This, UINT64 Position) {
			EfiLog("--> EfiFileProtocol.SetPosition(%s, %llu)\n", This->path.UTF8String, Position);
			if (This->fd != -1) {
				if (lseek(This->fd, Position, SEEK_SET) < 0) {
					return EFI_DEVICE_ERROR;
				}
				return EFI_SUCCESS;
			}
			return EFI_UNSUPPORTED;
		}),
		.GetPosition = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This, UINT64 *Position) {
			EfiLog("--> EfiFileProtocol.GetPosition(%s)\n", This->path.UTF8String);
			if (This->fd != -1) {
				
				off_t pos = lseek(This->fd, 0, SEEK_CUR);
				if (pos < 0) {
					return EFI_DEVICE_ERROR;
				}
				if (Position) {
					*Position = pos;
				}
				return EFI_SUCCESS;
			}
			return EFI_INVALID_PARAMETER;
		}),
		.GetInfo = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This, EFI_GUID *InformationType, UINTN *BufferSize, VOID *Buffer) {
			if (This->fd == -1) {
				EfiLog("--> EfiFileProtocol.GetInfo(%s, %s)\n", This->path.UTF8String, guid_str(InformationType));
				return EFI_INVALID_PARAMETER;
			}
			if (memcmp(InformationType, &EFI_FILE_INFO_GUID, sizeof(EFI_GUID)) == 0) {
				struct stat sbuf;
				
				EfiLog("--> EfiFileProtocol.GetInfo(%s, EFI_FILE_INFO_ID)\n", This->path.UTF8String);
				if (fstat(This->fd, &sbuf) < 0) {
					return EFI_DEVICE_ERROR;
				}
				NSData *utf16str = [This->path.lastPathComponent dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
				NSMutableData *dinfo = [NSMutableData dataWithLength:sizeof(EFI_FILE_INFO)];
				EFI_FILE_INFO *info = dinfo.mutableBytes;
				
				info->Size = sizeof(EFI_FILE_INFO) + utf16str.length;
				info->FileSize = sbuf.st_size;
				info->PhysicalSize = sbuf.st_blocks * ((sbuf.st_blocks / sbuf.st_size) + 1);
				info->CreateTime = efi_time_from_timespec(sbuf.st_birthtimespec);
				info->LastAccessTime = efi_time_from_timespec(sbuf.st_atimespec);
				info->ModificationTime = efi_time_from_timespec(sbuf.st_mtimespec);
				info->Attribute =
					((sbuf.st_flags & (UF_IMMUTABLE | SF_IMMUTABLE)) ? EFI_FILE_READ_ONLY : 0) |
					((sbuf.st_flags & UF_HIDDEN) ? EFI_FILE_HIDDEN : 0) |
					((sbuf.st_mode & S_IFMT) == S_IFDIR ? EFI_FILE_DIRECTORY : 0) |
					((sbuf.st_flags & SF_ARCHIVED) ? EFI_FILE_ARCHIVE : 0);
				[dinfo appendData:utf16str];
				if (*BufferSize < dinfo.length) {
					*BufferSize = dinfo.length;
					return EFI_BUFFER_TOO_SMALL;
				}
				*BufferSize = dinfo.length;
				memcpy(Buffer, dinfo.bytes, dinfo.length);
				return EFI_SUCCESS;
			} else if (memcmp(InformationType, &EFI_FILE_SYSTEM_INFO_GUID, sizeof(EFI_GUID)) == 0) {
				struct statfs fsbuf;
				
				EfiLog("--> EfiFileProtocol.GetInfo(%s, EFI_FILE_SYSTEM_INFO_ID)\n", This->path.UTF8String);
				if (fstatfs(This->fd, &fsbuf) < 0) {
					return EFI_DEVICE_ERROR;
				}
				NSURL *url = [NSURL fileURLWithPath:This->path];
				NSString *volname = nil;
				
				if (![url getResourceValue:&volname forKey:NSURLVolumeNameKey error:NULL]) {
					return EFI_DEVICE_ERROR;
				}
				NSData *utf16str = [volname dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
				NSMutableData *dinfo = [NSMutableData dataWithLength:sizeof(EFI_FILE_SYSTEM_INFO)];
				EFI_FILE_SYSTEM_INFO *info = dinfo.mutableBytes;
				
				info->Size = sizeof(EFI_FILE_SYSTEM_INFO) + utf16str.length;
				info->ReadOnly = (fsbuf.f_flags & MNT_RDONLY ? true : false);
				info->VolumeSize = (fsbuf.f_blocks * fsbuf.f_bsize);
				info->FreeSpace = (fsbuf.f_ffree * fsbuf.f_bsize);
				info->BlockSize = fsbuf.f_bsize;
				[dinfo appendData:utf16str];
				if (*BufferSize < dinfo.length) {
					*BufferSize = dinfo.length;
					return EFI_BUFFER_TOO_SMALL;
				}
				*BufferSize = dinfo.length;
				memcpy(Buffer, dinfo.bytes, dinfo.length);
				return EFI_SUCCESS;
			}
			return EFI_UNSUPPORTED;
		}),
		.SetInfo = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This, EFI_GUID *InformationType, UINTN BufferSize, VOID *Buffer) {
			EfiLog("--> EfiFileProtocol.SetInfo(%s, %s)\n", This->path.UTF8String, guid_str(InformationType));
			return EFI_UNSUPPORTED;
		}),
		.Flush = shim(^ EFI_STATUS (EFI_FILE_PROTOCOL_INTERNAL *This) {
			EfiLog("--> EfiFileProtocol.Flush(%s)\n", This->path.UTF8String);
			return EFI_UNSUPPORTED;
		}),
		},
		.path = @"\\",
		.fd = -1,
	};
	EFI_SIMPLE_FILE_SYSTEM_PROTOCOL fileSystemProtocol = {
		.Revision = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_REVISION,
		.OpenVolume = shim(^ EFI_STATUS (EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *This, EFI_FILE_PROTOCOL **Root) {
			*Root = (EFI_FILE_PROTOCOL *)&rootFileProtocol;
			return EFI_SUCCESS;
		}),
	};
	EFI_DATA_HUB_PROTOCOL_INTERNAL dataHubProtocol = {
		.Hub = {
		.LogData = shim(^ EFI_STATUS (EFI_DATA_HUB_PROTOCOL_INTERNAL *This, EFI_GUID *DataRecordGuid, EFI_GUID *ProducerName, UINT64 DataRecordClass,
									  VOID *RawData, UINT32 RawDataSize) {
			return noshim_LogData(This, DataRecordGuid, ProducerName, DataRecordClass, RawData, RawDataSize);
		}),
		.GetNextDataRecord = shim(^ EFI_STATUS(EFI_DATA_HUB_PROTOCOL_INTERNAL *This, UINT64 *MonotonicCount, EFI_EVENT *FilterDriver,
											   EFI_DATA_RECORD_HEADER **Record) {
			EfiLog("--> EfiDataHub.GetNextDataRecord(%llu, %p)\n", *MonotonicCount, FilterDriver);
			if (This->dataRecords.count < 1)
				return EFI_NOT_FOUND;
			if (*MonotonicCount == 0) {
				This->iteration = 0;
			}
			NSData *rec = This->dataRecords[This->iteration];
			
			if (*MonotonicCount != 0 && ((EFI_DATA_RECORD_HEADER *)rec.bytes)->LogMonotonicCount != *MonotonicCount) {
				return EFI_NOT_FOUND;
			}
			if (Record) {
				*Record = (EFI_DATA_RECORD_HEADER *)rec.bytes;
			}
			
			if (++This->iteration >= This->dataRecords.count) {
				*MonotonicCount = 0;
			} else {
				*MonotonicCount = ((EFI_DATA_RECORD_HEADER *)((NSData *)This->dataRecords[This->iteration]).bytes)->LogMonotonicCount;
			}
			return EFI_SUCCESS;
		}),
		.RegisterFilterDriver = shim(^ EFI_STATUS (EFI_DATA_HUB_PROTOCOL_INTERNAL *This, EFI_EVENT FilterEvent, EFI_TPL FilterTpl, UINT64 FilterClass,
												   EFI_GUID *FilterDataRecordGuid) {
			EfiLog("--> EfiDataHub.RegisterFilterDriver(%llu, %llu, %s)\n", FilterTpl, FilterClass, guid_str(FilterDataRecordGuid));
			return EFI_UNSUPPORTED;
		}),
		.UnregisterFilterDriver = shim(^ EFI_STATUS (EFI_DATA_HUB_PROTOCOL_INTERNAL *This, EFI_EVENT FilterEvent) {
			EfiLog("--> EfiDataHub.UnregisterFilterDriver()\n");
			return EFI_UNSUPPORTED;
		}),
		},
		.dataRecords = (__bridge NSMutableArray *)CFBridgingRetain(@[].mutableCopy),
		.iteration = 0,
	};
	APPLE_DEVICE_CONTROL_PROTOCOL appleDeviceControlProtocol = {
		.Unknown0 = 0,
		.ConnectDisplay = shim(^ EFI_STATUS (VOID) {
			EfiLog("--> AppleDeviceControl.ConnectDisplay()\n");
			return EFI_UNSUPPORTED;
		}),
		.Unknown2 = 0,
		.ConnectAll = shim(^ EFI_STATUS (VOID) {
			EfiLog("--> AppleDeviceControl.ConnectAll()\n");
			return EFI_UNSUPPORTED;
		}),
	};
	APPLE_SET_OS_PROTOCOL appleSetOSProtocol = {
		.Version = 2,
		.SetOSVersion = shim(^ VOID (const CHAR8 *OSVersion) {
			EfiLog("--> AppleSetOS.SetOSVersion(%s)\n", OSVersion);
		}),
		.SetOSVendor = shim(^ VOID (const CHAR8 *OSVendor) {
			EfiLog("--> AppleSetOS.SetOSVendor(%s)\n", OSVendor);
		}),
	};
	APPLE_FIRMWARE_PASSWORD_PROTOCOL appleFirmwarePasswordProtocol = {
		.Signature = 0,
		.Unknown = { 0, 0, 0 },
		.Check = shim(^ EFI_STATUS (APPLE_FIRMWARE_PASSWORD_PROTOCOL *This, UINTN *CheckValue) {
			EfiLog("--> AppleFirmwarePassword.Check(%p)\n", CheckValue);
			if (CheckValue) {
				*CheckValue = 0;
			}
			return EFI_SUCCESS;
		}),
	};
	APPLE_KEY_STATE_PROTOCOL appleKeyStateProtocol = {
		.Signature = 0,
		.ReadKeyState = shim(^ EFI_STATUS (APPLE_KEY_STATE_PROTOCOL *This, UINT16 *ModifyFlags, UINTN *PressedKeyStatesCount, CHAR16 *PressedKeyStates) {
			EfiLog("--> AppleKeyState.ReadKeyState()\n");
			*ModifyFlags = 0x04;
			*PressedKeyStatesCount = 0;
			return EFI_SUCCESS;
		}),
	};
	EFI_GRAPHICS_OUTPUT_PROTOCOL graphicsOutputProtocol = {
		.QueryMode = shim(^ EFI_STATUS (EFI_GRAPHICS_OUTPUT_PROTOCOL *This, UINT32 ModeNumber, UINTN *SizeOfInfo, EFI_GRAPHICS_OUTPUT_MODE_INFORMATION **Info) {
			EfiLog("--> EfiGraphicsOutput.QueryMode(%u)\n", ModeNumber);
			if (ModeNumber > 0) {
				return EFI_INVALID_PARAMETER;
			}
			*SizeOfInfo = sizeof(EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE);
			*Info = This->Mode->Info;
			return EFI_SUCCESS;
		}),
		.SetMode = shim(^ EFI_STATUS (EFI_GRAPHICS_OUTPUT_PROTOCOL *This, UINT32 ModeNumber) {
			EfiLog("--> EfiGraphicsOutput.SetMode(%u)\n", ModeNumber);
			if (ModeNumber > 0) {
				return EFI_INVALID_PARAMETER;
			}
			return EFI_SUCCESS;
		}),
		.Blt = shim(^ EFI_STATUS (EFI_GRAPHICS_OUTPUT_PROTOCOL *This, EFI_GRAPHICS_OUTPUT_BLT_PIXEL *BltBuffer, EFI_GRAPHICS_OUTPUT_BLT_OPERATION BltOperation,
								  UINTN SourceX, UINTN SourceY, UINTN DestinationX, UINTN DestinationY, UINTN Width, UINTN Height, UINTN Delta) {
			EfiLog("--> EfiGraphicsOutput.Blt(Operation = %s, X1 = %llu, Y1 = %llu, X2 = %llu, Y2 = %llu, W = %llu, H = %llu, D = %llu)\n",
				(char *[]){ "EfiBltVideoFill", "EfiBltVideoToBltBuffer", "EfiBltBufferToVideo", "EfiBltVideoToVideo" }[BltOperation],
				SourceX, SourceY, DestinationX, DestinationY, Width, Height, Delta
			);
			return EFI_SUCCESS;
		}),
		.Mode = (EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE [1]){{
			.MaxMode = 1,
			.Mode = 0,
			.Info = (EFI_GRAPHICS_OUTPUT_MODE_INFORMATION [1]){{
				.Version = 0,
				.HorizontalResolution = 1024,
				.VerticalResolution = 768,
				.PixelFormat = PixelRedGreenBlueReserved8BitPerColor,
				.PixelInformation = 0,
				.PixelsPerScanLine = 1024,
			}},
			.SizeOfInfo = sizeof(EFI_GRAPHICS_OUTPUT_MODE_INFORMATION),
			.FrameBufferBase = calloc(sizeof(UINT32), 1024 * 768),
			.FrameBufferSize = 1024 * 768 * sizeof(UINT32),
		}},
	};
	typedef struct {
		EFI_STATUS (*EFIAPI UnknownA)(VOID);
		EFI_STATUS (*EFIAPI UnknownB)(VOID);
		EFI_STATUS (*EFIAPI UnknownC)(VOID);
		EFI_STATUS (*EFIAPI UnknownD)(VOID);
		EFI_STATUS (*EFIAPI UnknownE)(VOID);
		EFI_STATUS (*EFIAPI UnknownF)(VOID);
		EFI_STATUS (*EFIAPI UnknownG)(VOID);
		EFI_STATUS (*EFIAPI UnknownH)(VOID);
		EFI_STATUS (*EFIAPI UnknownI)(VOID);
		EFI_STATUS (*EFIAPI UnknownJ)(VOID);
		EFI_STATUS (*EFIAPI UnknownK)(VOID);
		EFI_STATUS (*EFIAPI UnknownL)(VOID);
		EFI_STATUS (*EFIAPI UnknownM)(VOID);
		EFI_STATUS (*EFIAPI UnknownN)(VOID);
		EFI_STATUS (*EFIAPI UnknownO)(VOID);
		EFI_STATUS (*EFIAPI UnknownP)(VOID);
		EFI_STATUS (*EFIAPI UnknownQ)(VOID);
		EFI_STATUS (*EFIAPI UnknownR)(VOID);
		EFI_STATUS (*EFIAPI UnknownS)(VOID);
		EFI_STATUS (*EFIAPI UnknownT)(VOID);
		EFI_STATUS (*EFIAPI UnknownU)(VOID);
		EFI_STATUS (*EFIAPI UnknownV)(VOID);
		EFI_STATUS (*EFIAPI UnknownW)(VOID);
		EFI_STATUS (*EFIAPI UnknownX)(VOID);
		EFI_STATUS (*EFIAPI UnknownY)(VOID);
		EFI_STATUS (*EFIAPI UnknownZ)(VOID);
	} FAKE_PROTOCOL;
	FAKE_PROTOCOL fakeProtocol = {
		.UnknownA = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.A()\n"); return EFI_UNSUPPORTED; }),
		.UnknownB = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.B()\n"); return EFI_UNSUPPORTED; }),
		.UnknownC = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.C()\n"); return EFI_UNSUPPORTED; }),
		.UnknownD = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.D()\n"); return EFI_UNSUPPORTED; }),
		.UnknownE = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.E()\n"); return EFI_UNSUPPORTED; }),
		.UnknownF = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.F()\n"); return EFI_UNSUPPORTED; }),
		.UnknownG = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.G()\n"); return EFI_UNSUPPORTED; }),
		.UnknownH = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.H()\n"); return EFI_UNSUPPORTED; }),
		.UnknownI = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.I()\n"); return EFI_UNSUPPORTED; }),
		.UnknownJ = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.J()\n"); return EFI_UNSUPPORTED; }),
		.UnknownK = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.K()\n"); return EFI_UNSUPPORTED; }),
		.UnknownL = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.L()\n"); return EFI_UNSUPPORTED; }),
		.UnknownM = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.M()\n"); return EFI_UNSUPPORTED; }),
		.UnknownN = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.N()\n"); return EFI_UNSUPPORTED; }),
		.UnknownO = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.O()\n"); return EFI_UNSUPPORTED; }),
		.UnknownP = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.P()\n"); return EFI_UNSUPPORTED; }),
		.UnknownQ = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.Q()\n"); return EFI_UNSUPPORTED; }),
		.UnknownR = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.R()\n"); return EFI_UNSUPPORTED; }),
		.UnknownS = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.S()\n"); return EFI_UNSUPPORTED; }),
		.UnknownT = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.T()\n"); return EFI_UNSUPPORTED; }),
		.UnknownU = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.U()\n"); return EFI_UNSUPPORTED; }),
		.UnknownV = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.V()\n"); return EFI_UNSUPPORTED; }),
		.UnknownW = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.W()\n"); return EFI_UNSUPPORTED; }),
		.UnknownX = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.X()\n"); return EFI_UNSUPPORTED; }),
		.UnknownY = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.Y()\n"); return EFI_UNSUPPORTED; }),
		.UnknownZ = shim(^ EFI_STATUS (VOID) { EfiLog("--> FakeProtocol.Z()\n"); return EFI_UNSUPPORTED; }),
	};
	EFI_CPU_ARCH_PROTOCOL cpuArchProtocol = {
		.FlushDataCache = shim(^ EFI_STATUS (const EFI_CPU_ARCH_PROTOCOL *This, EFI_PHYSICAL_ADDRESS Start, UINT64 Length, EFI_CPU_FLUSH_TYPE FlushType) {
			EfiLog("--> EfiCpuArch.FlushDataCache(%p, %llu, %d)\n", (void *)Start, Length, FlushType);
			return EFI_UNSUPPORTED;
		}),
		.EnableInterrupt = shim(^ EFI_STATUS (const EFI_CPU_ARCH_PROTOCOL *This) {
			EfiLog("--> EfiCpuArch.EnableInterrupt()\n");
			return EFI_UNSUPPORTED;
		}),
		.DisableInterrupt = shim(^ EFI_STATUS (const EFI_CPU_ARCH_PROTOCOL *This) {
			EfiLog("--> EfiCpuArch.DisableInterrupt()\n");
			return EFI_UNSUPPORTED;
		}),
		.GetInterruptState = shim(^ EFI_STATUS (const EFI_CPU_ARCH_PROTOCOL *This, BOOLEAN *State) {
			EfiLog("--> EfiCpuArch.GetInterruptState()\n");
			return EFI_UNSUPPORTED;
		}),
		.Init = shim(^ EFI_STATUS (const EFI_CPU_ARCH_PROTOCOL *This, EFI_CPU_INIT_TYPE InitType) {
			EfiLog("--> EfiCpuArch.Init(%d)\n", InitType);
			return EFI_UNSUPPORTED;
		}),
		.RegisterInterruptHandler = shim(^ EFI_STATUS (const EFI_CPU_ARCH_PROTOCOL *This, EFI_EXCEPTION_TYPE InterruptType,
													   EFI_CPU_INTERRUPT_HANDLER InterruptHandler) {
			EfiLog("--> EfiCpuArch.RegisterInterruptHandler(%lld, %p)\n", InterruptType, InterruptHandler);
			return EFI_UNSUPPORTED;
		}),
		.GetTimerValue = shim(^ EFI_STATUS (const EFI_CPU_ARCH_PROTOCOL *This, UINT32 TimerIndex, UINT64 *TimerValue, UINT64 *TimerPeriod) {
			if (TimerIndex > 0 || TimerValue == NULL)
				return EFI_INVALID_PARAMETER;
			struct timeval tv = { 0, 0 };
			
			gettimeofday(&tv, NULL);
			*TimerValue = (tv.tv_sec * USEC_PER_SEC) + tv.tv_usec;
			if (TimerPeriod) {
				*TimerPeriod = NSEC_PER_USEC * 1000;
			}
			return EFI_SUCCESS;
		}),
		.SetMemoryAttributes = shim(^ EFI_STATUS (const EFI_CPU_ARCH_PROTOCOL *This, EFI_PHYSICAL_ADDRESS BaseAddress, UINT64 Length, UINT64 Attributes) {
			EfiLog("--> EfiCpuArch.SetMemoryAttributes(%p, %llu, %llu)\n", (void *)BaseAddress, Length, Attributes);
			return EFI_UNSUPPORTED;
		}),
		.NumberOfTimers = 1,
		.DmaBufferAlignment = 1048576,
	};
	#define FakeFunc(name) .name = shim(^ { NSLog(@"Unimplemented %s", #name); return EFI_UNSUPPORTED; })
	EFI_BOOT_SERVICES bootServices = {
		.Hdr = { EFI_BOOT_SERVICES_SIGNATURE, EFI_BOOT_SERVICES_REVISION, sizeof(EFI_BOOT_SERVICES), 0, 0 },
		FakeFunc(RaiseTPL),
		FakeFunc(RestoreTPL),
		.AllocatePages = shim(^ EFI_STATUS (EFI_ALLOCATE_TYPE Type, EFI_MEMORY_TYPE MemoryType, UINTN Pages, EFI_PHYSICAL_ADDRESS *Memory) {
			if (MemoryType > EfiMaxMemoryType)
				return EFI_INVALID_PARAMETER;
			if (Type == AllocateAnyPages) {
				EfiLog("--> AllocatePages(AllocateAnyPages, %d, %llu)\n", MemoryType, Pages);
				*Memory = mmap(NULL, Pages * getpagesize(), PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
			} else if (Type == AllocateMaxAddress) {
				EfiLog("--> AllocatePages(AllocateMaxAddress, %d, %llu, %p)\n", MemoryType, Pages, (VOID *)*Memory);
				*Memory = mmap(*Memory - ((Pages + 5) * getpagesize()), PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, MAP_ANON | MAP_PRIVATE, -1, 0);
			} else if (Type == AllocateAddress) {
				EfiLog("--> AllocatePages(AllocateAddress, %d, %llu, %p)\n", MemoryType, Pages, (VOID *)*Memory);
				*Memory = mmap(*Memory, Pages * getpagesize(), PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_FIXED | MAP_PRIVATE, -1, 0);
			}
			if ((VOID *)*Memory == MAP_FAILED)
				return EFI_OUT_OF_RESOURCES;
			EfiLog("<-- %p\n", (void *)*Memory);
			return EFI_SUCCESS;
		}),
		.FreePages = shim(^ EFI_STATUS (EFI_PHYSICAL_ADDRESS Memory, UINTN Pages) {
			if (munmap((VOID *)Memory, Pages * getpagesize()) < 0)
				return EFI_SUCCESS;//return EFI_NOT_FOUND;
			return EFI_SUCCESS;
		}),
		FakeFunc(GetMemoryMap),
		.AllocatePool = shim(^ EFI_STATUS (EFI_MEMORY_TYPE PoolType, UINTN Size, VOID **Buffer) {
			UINTN RealSize = (Size % 4096) == 0 ? Size : (Size + 4096 - (Size % 4096));
//			EfiLog("--> AllocatePool(%d, %llu/%llu): ", PoolType, Size, RealSize);
			if (PoolType > EfiMaxMemoryType) {
//				EfiLog("Bad memory type\n");
				return EFI_INVALID_PARAMETER;
			}
			*Buffer = malloc(RealSize);
			if (!*Buffer) {
//				EfiLog("Allocation failure\n");
				return EFI_OUT_OF_RESOURCES;
			}
//			EfiLog("%p\n", *Buffer);
			return EFI_SUCCESS;
		}),
		.FreePool = shim(^ EFI_STATUS (VOID *Buffer) {
			free(Buffer);
			return EFI_SUCCESS;
		}),
		FakeFunc(CreateEvent),
		FakeFunc(SetTimer),
		FakeFunc(WaitForEvent),
		FakeFunc(SignalEvent),
		FakeFunc(CloseEvent),
		FakeFunc(CheckEvent),
		FakeFunc(InstallProtocolInterface),
		FakeFunc(ReinstallProtocolInterface),
		FakeFunc(UninstallProtocolInterface),
		.HandleProtocol = shim(^ EFI_STATUS (EFI_HANDLE *Handle, EFI_GUID *Protocol, VOID **Interface) {
			if (!Handle)
				return EFI_INVALID_PARAMETER;
			if (memcmp(Protocol, &EFI_LOADED_IMAGE_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> HandleProtocol(%p, EFI_LOADED_IMAGE_PROTOCOL)\n", Handle);
				*Interface = (VOID *)&loadedImageProtocol;
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &EFI_DEVICE_PATH_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> HandleProtocol(%p, EFI_DEVICE_PATH_PROTOCOL)\n", Handle);
				if (Handle == loadedImageProtocol.DeviceHandle) {
					*Interface = (VOID *)&devicePathProtocol;
					return EFI_SUCCESS;
				} else {
					return EFI_NOT_FOUND;
				}
			} else if (memcmp(Protocol, &EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> HandleProtocol(%p, EFI_SIMPLE_FILE_SYSTEM_PROTOCOL)\n", Handle);
				*Interface = (VOID *)&fileSystemProtocol;
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> HandleProtocol(%p, EFI_GRAPHICS_OUTPUT_PROTOCOL)\n", Handle);
				*Interface = (VOID *)&graphicsOutputProtocol;
				return EFI_SUCCESS;
			}
			EfiLog("--> HandleProtocol(%p, %s)\n", Handle, guid_str(Protocol));
			return EFI_NOT_FOUND;
		}),
		.Reserved = NULL,
		FakeFunc(RegisterProtocolNotify),
		FakeFunc(LocateHandle),
		FakeFunc(LocateDevicePath),
		FakeFunc(InstallConfigurationTable),
		FakeFunc(LoadImage),
		FakeFunc(StartImage),
		.Exit = shim(^ EFI_STATUS (EFI_HANDLE ImageHandle, EFI_STATUS ExitStatus, UINTN ExitDataSize, CHAR16 *ExitData) {
			EfiLog("--> Exit(%p, %llu, %llu, %p)\n", ImageHandle, ExitStatus & ~0x8000000000000000, ExitDataSize, ExitData);
			longjmp(jb, ExitStatus);
		}),
		FakeFunc(UnloadImage),
		FakeFunc(ExitBootServices),
		FakeFunc(GetNextMonotonicCount),
		.Stall = shim(^ EFI_STATUS (UINTN Microseconds) {
			EfiLog("--> Stall(%llu)\n", Microseconds);
			usleep(Microseconds);
			return EFI_SUCCESS;
		}),
		FakeFunc(SetWatchdogTimer),
		FakeFunc(ConnectController),
		FakeFunc(DisconnectController),
		FakeFunc(OpenProtocol),
		FakeFunc(CloseProtocol),
		FakeFunc(OpenProtocolInformation),
		FakeFunc(ProtocolsPerHandle),
		FakeFunc(LocateHandleBuffer),
		.LocateProtocol = shim(^ EFI_STATUS (EFI_GUID *Protocol, VOID *Registration, VOID **Interface) {
			EFI_GUID g = { 0x03622d6d, 0x362a, 0x4e47, { 0x97, 0x10, 0xc2, 0x38, 0xb2, 0x37, 0x55, 0xc1 } };
			if (memcmp(Protocol, &EFI_CONSOLE_CONTROL_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> LocateProtocol(EFI_CONSOLE_CONTROL_PROTOCOL, %p)\n", Registration);
				if (Interface) {
					*Interface = (VOID *)&consoleControlProtocol;
				}
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &EFI_DATA_HUB_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> LocateProtocol(EFI_DATA_HUB_PROTOCOL, %p)\n", Registration);
				if (Interface) {
					*Interface = (VOID *)&dataHubProtocol;
				}
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &APPLE_DEVICE_CONTROL_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> LocateProtocol(APPLE_DEVICE_CONTROL_PROTOCOL_GUID, %p)\n", Registration);
				if (Interface) {
					*Interface = (VOID *)&appleDeviceControlProtocol;
				}
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &g, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> LocateProtocol(UNKNOWN, %p)\n", Registration);
				if (Interface) {
					*Interface = (VOID *)&fakeProtocol;
				}
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &EFI_CPU_ARCH_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> LocateProtocol(EFI_CPU_ARCH_PROTOCOL, %p)\n", Registration);
				if (Interface) {
					*Interface = (VOID *)&cpuArchProtocol;
				}
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &APPLE_SET_OS_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> LocateProtocol(APPLE_SET_OS_PROTOCOL, %p)\n", Registration);
				if (Interface) {
					*Interface = (VOID *)&appleSetOSProtocol;
				}
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &APPLE_FIRMWARE_PASSWORD_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> LocateProtocol(APPLE_FIRMWARE_PASSWORD_PROTOCOL, %p)\n", Registration);
				if (Interface) {
					*Interface = (VOID *)&appleFirmwarePasswordProtocol;
				}
				return EFI_SUCCESS;
			} else if (memcmp(Protocol, &APPLE_KEY_STATE_PROTOCOL_GUID, sizeof(EFI_GUID)) == 0) {
				EfiLog("--> LocateProtocol(APPLE_KEY_STATE_PROTOCOL, %p)\n", Registration);
				if (Interface) {
					*Interface = (VOID *)&appleKeyStateProtocol;
				}
				return EFI_SUCCESS;
			}
			EfiLog("--> LocateProtocol(%s, %p)\n", guid_str(Protocol), Registration);
			return EFI_NOT_FOUND;
		}),
		FakeFunc(InstallMultipleProtocolInterfaces),
		FakeFunc(UninstallMultipleProtocolInterfaces),
		FakeFunc(CalculateCrc32),
		.CopyMem = shim(^ VOID (VOID *Destination, VOID *Source, UINTN Length) {
			EfiLog("--> CopyMem(%p, %p, %llu)\n", Destination, Source, Length);
			memmove(Destination, Source, Length);
		}),
		.SetMem = shim(^ VOID (VOID *Buffer, UINTN Size, UINT8 Value) {
			EfiLog("--> SetMem(%p, %llu, %hhu)\n", Buffer, Size, Value);
			memset(Buffer, Value, Size);
		}),
		FakeFunc(CreateEventEx),
	};
	EFI_RUNTIME_SERVICES runtimeServices = {
		.Hdr = { EFI_RUNTIME_SERVICES_SIGNATURE, EFI_RUNTIME_SERVICES_REVISION, sizeof(EFI_RUNTIME_SERVICES), 0, 0 },
		FakeFunc(GetTime),
		FakeFunc(SetTime),
		FakeFunc(GetWakeupTime),
		FakeFunc(SetWakeupTime),
		FakeFunc(SetVirtualAddressMap),
		FakeFunc(ConvertPointer),
		.GetVariable = shim(^ EFI_STATUS (CHAR16 *VariableName, EFI_GUID *VendorGuid, UINT32 *Attributes, UINTN *DataSize, VOID *Data) {
			EfiLog("--> GetVariable(%s, %p, %llu, %p)\n", utf8_str(VariableName), Attributes, *DataSize, Data);
//			EfiLog("--> GetVariable(%s, %s, %p, %llu, %p)\n", utf8_str(VariableName), guid_str(VendorGuid), Attributes, *DataSize, Data);
			
			NSString *varNameStr = [NSString stringWithFormat:@"%s.%@", guid_str(VendorGuid),
											 [NSString stringWithCharacters:VariableName length:wstrlen(VariableName)]];
			if (efiVars[varNameStr]) {
				NSData *varData = efiVars[varNameStr];
				
				if (varData.length > *DataSize) {
					*DataSize = varData.length;
					return EFI_BUFFER_TOO_SMALL;
				}
				[varData getBytes:Data length:MIN(*DataSize, varData.length)];
				*DataSize = varData.length;
				if (Attributes) {
					*Attributes = EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS | EFI_VARIABLE_NON_VOLATILE;
				}
				return EFI_SUCCESS;
			}
			return EFI_NOT_FOUND;
		}),
		FakeFunc(GetNextVariableName),
		.SetVariable = shim(^ EFI_STATUS (CHAR16 *VariableName, EFI_GUID *VendorGuid, UINT32 Attributes, UINTN DataSize, VOID *Data) {
			EfiLog("--> SetVariable(%s, 0x%x, %llu, %p)\n", utf8_str(VariableName), Attributes, DataSize, Data);
//			EfiLog("--> SetVariable(%s, %s, 0x%x, %llu, %p)\n", utf8_str(VariableName), guid_str(VendorGuid), Attributes, DataSize, Data);
			
			NSString *varNameStr = [NSString stringWithFormat:@"%s.%@", guid_str(VendorGuid),
											 [NSString stringWithCharacters:VariableName length:wstrlen(VariableName)]];
			
			if (DataSize || (Attributes & EFI_VARIABLE_APPEND_WRITE)) {
				efiVars[varNameStr] = [NSData dataWithBytes:Data length:DataSize];
			} else {
				[efiVars removeObjectForKey:varNameStr];
			}
			return EFI_SUCCESS;
		}),
		FakeFunc(GetNextHighMonotonicCount),
		.ResetSystem = shim(^ VOID __attribute__((noreturn)) (EFI_RESET_TYPE ResetType, EFI_STATUS ResetStatus, UINTN DataSize, VOID *ResetData) {
			EfiLog("--> ResetSystem(%s, %llx)\n", ResetType == EfiResetCold ? "Cold" : (ResetType == EfiResetWarm ? "Warm" : "Shutdown"), ResetStatus);
			longjmp(jb, 0);
		}),
		FakeFunc(UpdateCapsule),
		FakeFunc(QueryCapsuleCapabilities),
		FakeFunc(QueryVariableInfo),
	};
	EFI_SYSTEM_TABLE st = {
		.Hdr = { EFI_SYSTEM_TABLE_SIGNATURE, EFI_SYSTEM_TABLE_REVISION, sizeof(EFI_SYSTEM_TABLE), 0, 0 },
		.FirmwareVendor = (CHAR16 *)"F\0a\0k\0e\0 \0E\0F\0I\0\0\0",
		.FirmwareRevision = 0,
		.ConsoleInHandle = (EFI_HANDLE)0xabad1deadeadbee4,
		.ConIn = &inputProtocol,
		.ConsoleOutHandle = (EFI_HANDLE)0xabad1deadeadbeef,
		.ConOut = &outputProtocol,
		.StandardErrorHandle = (EFI_HANDLE)0xabad1deadeadbee5,
		.StdErr = &outputProtocol,
		.RuntimeServices = &runtimeServices,
		.BootServices = &bootServices,
		.NumberOfTableEntries = 0,
		.ConfigurationTable = NULL,
	};
	EFI_HANDLE ih = (EFI_HANDLE)0xabad1deadeadbee7;
	EFI_STATUS result = EFI_SUCCESS;
	
	st.Hdr.CRC32 = crc32((uint8_t *)&st, st.Hdr.HeaderSize);
	bootServices.Hdr.CRC32 = crc32((uint8_t *)&bootServices, bootServices.Hdr.HeaderSize);
	runtimeServices.Hdr.CRC32 = crc32((uint8_t *)&runtimeServices, runtimeServices.Hdr.HeaderSize);
	loadedImageProtocol.SystemTable = &st;
	
	// A region apparently required by the bootloader
	if (mmap(0xfffff000, 0x1000, PROT_READ | PROT_WRITE, MAP_ANON | MAP_FIXED | MAP_PRIVATE, -1, 0) == MAP_FAILED) {
		NSLog(@"Can't allocate highmem region for bootloader, bailing");
		return EFI_ABORTED;
	}
	static const uint8_t bytes[] = {
		0x22, 0xe0, 0x66, 0xb8, 0x08, 0x00, 0x8e, 0xd8, 0x8e, 0xc0, 0x8e, 0xe0, 0x8e, 0xe8, 0x8e, 0xd0,
		0xe9, 0xa1, 0x00, 0x00, 0x00, 0x66, 0xbc, 0x78, 0x56, 0x34, 0x12, 0xbf, 0x41, 0x50, 0x2e, 0x66,
		0x0f, 0x01, 0x16, 0x21, 0x00, 0x66, 0xb8, 0x23, 0x00, 0x00, 0x40, 0x0f, 0x22, 0xc0, 0x66, 0xea,
		0x02, 0xff, 0xff, 0xff, 0x10, 0x00, 0x2f, 0x00, 0x50, 0xff, 0xff, 0xff, 0x90, 0x90, 0x90, 0x90,
		0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0xff, 0xff, 0x00, 0x00, 0x00, 0x93, 0xcf, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x9b, 0xcf, 0x00,
		0xff, 0xff, 0x00, 0x00, 0x00, 0x9b, 0xaf, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x9b, 0x8f, 0x00,
		0xff, 0xff, 0x00, 0x00, 0x00, 0x93, 0x8f, 0x00, 0x89, 0xc7, 0xb0, 0x02, 0xe6, 0x92, 0x89, 0xf8,
		0xbf, 0x42, 0x50, 0xeb, 0x2c, 0x66, 0x89, 0xc4, 0xe9, 0x28, 0x00, 0x89, 0xe3, 0xb8, 0x01, 0x00,
		0x00, 0x00, 0xf3, 0x90, 0x3b, 0x03, 0x74, 0xfa, 0x87, 0x03, 0x85, 0xc0, 0x75, 0xf4, 0x8b, 0x63,
		0x08, 0x53, 0xff, 0x53, 0x04, 0x31, 0xc0, 0x89, 0x03, 0xf0, 0xff, 0x43, 0x0c, 0xfa, 0xf4, 0xeb,
		0xfc, 0xeb, 0xd2, 0xe9, 0x2b, 0xff, 0x66, 0x81, 0xff, 0x41, 0x50, 0x74, 0xce, 0xe9, 0xf6, 0xfd,
		0xff, 0xff, 0xe9, 0x48, 0xfe, 0xff, 0xff, 0x89, 0xe0, 0xff, 0xe6, 0x90, 0x90, 0x90, 0x90, 0x90,
		0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x1d, 0xff, 0xff, 0xff, 0x27, 0x00, 0x90, 0x90,
		0x00, 0x00, 0x00, 0x00, 0x56, 0x54, 0x46, 0x00, 0x0f, 0x09, 0xe9, 0x8b, 0xff, 0x90, 0x90, 0x90,
	};
#undef memcpy
	memcpy(0xffffff08, bytes, MIN(sizeof(bytes), 0xffu-0x08u));
	
	//0x000000000001333c B998010000                      movl       $0x198, %ecx
	//0x0000000000013341 0F32                            rdmsrl     
	uint8_t *r = mmap(0, 4096, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_FIXED | MAP_PRIVATE, -1, 0);
	
	if (r == MAP_FAILED) {
		NSLog(@" Can't allocate jump islands, bailing");
		return EFI_ABORTED;
	}

	union msr_patch {
		struct {
			uint8_t mov_op;
			uint32_t msr_selector;
			uint16_t msr_op;
		} __attribute__((packed)) orig_instrs;
		struct {
			uint8_t call_ops[3];
			uint32_t call_addr;
		} __attribute__((packed)) tramp_instrs;
	} __attribute__((packed)) msr_u;
	
	uint8_t *begin = 0x1000, *end = 0x33000, *p = begin;
	uint64_t *nextTrampoline = (uint64_t *)(r + 16);
	
	while (p && p < end) {
		p = memmem(p, end - p, (uint8_t[2]){ 0x0f, 0x32 }, 2);
		if (p) {
			EfiLog("+++ Patching rdmsr instruction at %p using trampoline at %p...\n", p, nextTrampoline);
			union msr_patch *patch = (union msr_patch *)(p - 5);
			uint32_t selector = patch->orig_instrs.msr_selector;
			void *block = shim(^ msr_result { return deal_with_msr(selector); });
			
			NSCAssert(nextTrampoline < (uint64_t *)4096, @"trampolines must fit in that one damned page");
			*nextTrampoline = (uint64_t)(uintptr_t)block;
			patch->tramp_instrs.call_ops[0] = 0xff;
			patch->tramp_instrs.call_ops[1] = 0x14;
			patch->tramp_instrs.call_ops[2] = 0x25;
			patch->tramp_instrs.call_addr = (uint32_t)((uintptr_t)nextTrampoline & 0x00000000ffffffff);
			++nextTrampoline;
			p += 2;
		}
	}

//#undef memcpy
//	memcpy(0x12e30, &__hack_jumper, 7);
//	*(uint64_t *)(r + 0) = r + 16;
//	*(uint64_t *)(r + 8) = 0x12e3a;
//	memcpy(r + 16, &__hack_debug_region, 48);
//	*(uint8_t *)(0x1301e) = 0x01;
	
//	uint64_t *pp = (uint64_t *)0x13017;
//	id block = ^ (const char *s) {
//		printf(">>> %s\n", s);
//	};
//	
//	*pp = 0x90000000002514ff; // callq *0x0; nop
//	*(uint64_t *)(r +  0) = &__hack_debug_logs;
//	*(uint64_t *)(r +  8) = shim(block);
	
//	*((uint8_t *)0x1310f) = 0x75;
	
	p = 0x130f8;
	*p++ = 0xff;
	*p++ = 0x14;
	*p++ = 0x25;
	*(uint32_t *)p = nextTrampoline;
	*nextTrampoline = (uint64_t)(uintptr_t)(uint8_t *)shim(^ void (const CHAR8 *s) {
		printf("*** %s\n", s);
	});
	p += 4;
	*p++ = 0x48;
	*p++ = 0x83;
	*p++ = 0xc4;
	*p++ = 0x40;
	*p++ = 0x5d;
	*p++ = 0xc3;
	
//	EFI_GUID FsbFrequencyPropertyGuid = { 0xd1a0dD55, 0x75b9, 0x41a3, { 0x90, 0x36, 0x8f, 0x4a, 0x26, 0x1c, 0xbb, 0xa2 } };
//	EFI_GUID DevicePathsSupportedGuid = { 0x5bb91cf7, 0xd816, 0x404b, { 0x86, 0x72, 0x68, 0xf2, 0x7f, 0x78, 0x31, 0xdc } };
	EFI_GUID specialGuid = { 0x64517cc8, 0x6561, 0x4051, { 0xb0, 0x3c, 0x59, 0x64, 0xb6, 0x0f, 0x4c, 0x7a } };

	setprop(&dataHubProtocol.Hub, (CHAR16 *)"F\0S\0B\0F\0r\0e\0q\0u\0e\0n\0c\0y\0\0\0", specialGuid, (UINT64[]){ 200000000 }, sizeof(UINT64));
	setprop(&dataHubProtocol.Hub, (CHAR16 *)"D\0e\0v\0i\0c\0e\0P\0a\0t\0h\0s\0S\0u\0p\0p\0o\0r\0t\0e\0d\0\0\0", specialGuid, (UINT32[]){ 1 }, sizeof(UINT32));
	setprop(&dataHubProtocol.Hub, (CHAR16 *)"M\0o\0d\0e\0l\0\0\0", specialGuid, (VOID *)"M\0a\0c\0B\0o\0o\0k\0A\0i\0r\06\0,\02\0\0\0", 30);
		
	if ((result = setjmp(jb)) == 0) {
		__asm__ (
			"call *%3" :
			"=a" (result) :
			"c" (ih), "d" (&st), "r" (loader.entryPoint) :
			"memory", "r8", "r9", "r10", "r11", "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5"
		);
	}
	return result;
}

static void __attribute__((naked,used,noinline)) __hack_debug_logs(void)
{
	__asm__ __volatile__ (
		"push %%rbp\n\t"
		"mov %%rsp, %%rbp\n\t"
		"push %%rax\n\t"
		"push %%rbx\n\t"
		"call *0x8\n\t"
		"xor %%eax, %%eax\n\t"
		"mov $0x1303a, %%rbx\n\t"
		"cmpq $0x0, 0x7a6e0(%%rax)\n\t"
		"movq $0x13021, %%rax\n\t"
		"cmoveq %%rbx, %%rax\n\t"
		"mov %%rax, 0x8(%%rbp)\n\t"
		"pop %%rbx\n\t"
		"pop %%rax\n\t"
		"pop %%rbp\n\t"
		"ret"
		:
		:
	);
}

static msr_result deal_with_msr(uint32_t which)
{
	EfiLog("+++ Need MSR value for selector 0x%x\n", which);
	return (msr_result){ 0, 0 };
}

static void __attribute__((naked,used,noinline)) __hack_jumper(void)
{
	__asm__ __volatile__ (
		"jmp *0x1000\n\t"
		"nop" :
		:
		:
	);
}

static void __attribute__((naked,used,noinline)) __hack_debug_region(void)
{
	__asm__ __volatile__ (
		"sub $0x48, %%rsp\n\t"
		"mov $0x1030, %%rcx\n\t"
		"mov %%rdx, %%rsi\n\t"
		"jmp *0x1008"
		:
		:
	);
}

int main(int argc, const char **argv)
{
	@autoreleasepool
	{
		if (argc == 2) {
			NSError *error = nil;
			PELoader *loader = [[PELoader alloc] initWithURL:[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]] error:&error];
			
			if (!loader) {
				NSLog(@"Failed to load: %@", error);
			}
			
			if (![loader mapAndReturnError:&error]) {
				NSLog(@"Failed to map: %@", error);
			}
			
			setvbuf(stdin, NULL, _IONBF, 0);
			setvbuf(stdout, NULL, _IONBF, 0);
			setvbuf(stderr, NULL, _IONBF, 0);
			NSLog(@"%llu", callEntryPoint(loader));
		}
	}
	return 0;
}
