#pragma once

#ifdef __cplusplus

#define FIRMWARE_VERSION_MAJOR 1
#define FIRMWARE_VERSION_MINOR 3
#define FIRMWARE_VERSION_PATCH 0

extern char const* kFirmwareVersionString;
extern char const* kFirmwareVersionStringShort;

#else

extern char const* kCommitShort;

#endif
