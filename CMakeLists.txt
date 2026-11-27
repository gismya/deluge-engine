# deluge-engine: the Deluge firmware's own code built for macOS arm64 (spec §3.3).
#
#   cmake -S . -B build/release -G Ninja -DCMAKE_BUILD_TYPE=Release                    (-O2)
#   cmake -S . -B build/asan    -G Ninja -DCMAKE_BUILD_TYPE=Debug -DDELUGE_SANITIZE=ON  (-O1, ASan + UBSan)
#
# tools/check.py runs both, as CI does. Build output goes under build/, which is never tracked.
cmake_minimum_required(VERSION 3.25)
cmake_policy(SET CMP0135 NEW)
project(deluge_engine LANGUAGES C CXX)

# Spec §11: release at -O2 (CMake's default is -O3 -DNDEBUG; the firmware never sets NDEBUG either).
set(CMAKE_C_FLAGS_RELEASE "-O2 -g" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_RELEASE "-O2 -g" CACHE STRING "" FORCE)

set(DELUGE_FIRMWARE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/firmware" CACHE PATH
    "The firmware checkout to build: the submodule, or a worktree with unmerged Generative work")
option(DELUGE_SANITIZE "Build with AddressSanitizer and UndefinedBehaviorSanitizer" OFF)

if(NOT EXISTS "${DELUGE_FIRMWARE_DIR}/src/deluge/deluge.cpp")
  message(FATAL_ERROR "No firmware at ${DELUGE_FIRMWARE_DIR}: run `git submodule update --init firmware`")
endif()
if(NOT APPLE OR NOT CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")
  message(WARNING "deluge-engine targets macOS arm64; ${CMAKE_SYSTEM_NAME} ${CMAKE_SYSTEM_PROCESSOR} is untested")
endif()

find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_package(Git REQUIRED)

# The firmware needs a compiler that implements P2280 (references with unknown values in constant expressions):
# enum_to_string_map.hpp static_asserts on std::size() of a reference parameter. Apple clang 21 builds it; Apple
# clang 17 (Xcode 16.x and early 26.x) doesn't (docs/implementation-notes.md). Probe the construct itself, so an old
# compiler fails here with this message instead of deep in gui/ui/ui.cpp.
include(CheckCXXSourceCompiles)
set(CMAKE_REQUIRED_FLAGS "-std=gnu++23")
check_cxx_source_compiles([=[
#include <array>
#include <cstddef>
template <std::size_t N> struct Probe {
  constexpr Probe(const std::array<int, N>& init) { static_assert(N == std::size(init)); }
};
int main() { constexpr std::array<int, 2> a{1, 2}; Probe<2> p(a); (void)p; }
]=] DELUGE_COMPILER_HAS_P2280)
unset(CMAKE_REQUIRED_FLAGS)
if(NOT DELUGE_COMPILER_HAS_P2280)
  message(FATAL_ERROR "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} is too old for the firmware: it doesn't "
    "implement P2280 (unknown references in constant expressions). Use Apple clang 21 or newer (Xcode 26.6 has it); "
    "see docs/implementation-notes.md.")
endif()

# The argon and etl pins come from the firmware's own list (spec §3.3), not repeated here. Both build configurations
# share one download folder.
include(FetchContent)
if(NOT FETCHCONTENT_BASE_DIR OR FETCHCONTENT_BASE_DIR STREQUAL "${CMAKE_BINARY_DIR}/_deps")
  set(FETCHCONTENT_BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/build/_deps" CACHE PATH "" FORCE)
endif()
include("${DELUGE_FIRMWARE_DIR}/lib/CMakeLists.txt")

set(FW "${DELUGE_FIRMWARE_DIR}")
set(GEN "${CMAKE_BINARY_DIR}/gen")

# ---- Generated files: the host register headers and the firmware's version files, all under build/.
set(GEN_HOST_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/engine/platform/gen_host_headers.py")
file(GLOB FW_IODEFINES CONFIGURE_DEPENDS "${FW}/src/RZA1/system/iodefines/*.h")
add_custom_command(
  OUTPUT "${GEN}/host/RZA1/cpu_specific.h" "${GEN}/host/RZA1/system/iodefine.h"
  COMMAND "${Python3_EXECUTABLE}" "${GEN_HOST_HEADERS}" "${FW}/src" "${GEN}/host"
  DEPENDS "${GEN_HOST_HEADERS}" "${FW}/src/RZA1/cpu_specific.h" "${FW}/src/RZA1/system/iodefine.h" ${FW_IODEFINES}
  COMMENT "Generating host RZ/A1 headers"
  VERBATIM)
add_custom_target(host_headers DEPENDS "${GEN}/host/RZA1/cpu_specific.h" "${GEN}/host/RZA1/system/iodefine.h")
# Configure-time run too, so a fresh configure fails at once on a raw peripheral address.
execute_process(COMMAND "${Python3_EXECUTABLE}" "${GEN_HOST_HEADERS}" "${FW}/src" "${GEN}/host"
  RESULT_VARIABLE gen_result)
if(NOT gen_result EQUAL 0)
  message(FATAL_ERROR "gen_host_headers.py failed")
endif()

file(READ "${FW}/CMakeLists.txt" fw_cmake)
string(REGEX MATCH "VERSION ([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ "${fw_cmake}")
set(PROJECT_VERSION_MAJOR ${CMAKE_MATCH_1})
set(PROJECT_VERSION_MINOR ${CMAKE_MATCH_2})
set(PROJECT_VERSION_PATCH ${CMAKE_MATCH_3})
set(PROJECT_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
execute_process(COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD WORKING_DIRECTORY "${FW}"
  OUTPUT_VARIABLE GIT_COMMIT_SHORT OUTPUT_STRIP_TRAILING_WHITESPACE)
set(BUILD_VERSION_STRING "${PROJECT_VERSION}-engine-${GIT_COMMIT_SHORT}")
set(BUILD_VERSION_STRING_SHORT "c${PROJECT_VERSION}")
configure_file("${FW}/src/deluge/version/version.h.in" "${GEN}/version.h" @ONLY)
configure_file("${FW}/src/deluge/version/version.cpp.in" "${GEN}/version.cpp.gen" @ONLY)
configure_file("${FW}/src/deluge/util/firmware_version.h.in" "${GEN}/util/firmware_version.h" @ONLY)

# ---- Firmware sources: compiled in place from the checkout, never copied (spec §2, §3.2).
file(GLOB_RECURSE FW_SOURCES CONFIGURE_DEPENDS
  "${FW}/src/deluge/*.c" "${FW}/src/deluge/*.cpp"
  "${FW}/src/OSLikeStuff/*.c" "${FW}/src/OSLikeStuff/*.cpp"
  "${FW}/src/fatfs/*.c" "${FW}/src/fatfs/*.cpp"
  "${FW}/src/lib/*.c")
# Hardware drivers and code the host replaces (engine/platform). The allocator stays 32-bit on purpose (spec §3.5).
list(FILTER FW_SOURCES EXCLUDE REGEX "/src/deluge/drivers/")
list(FILTER FW_SOURCES EXCLUDE REGEX "/src/OSLikeStuff/timers_interrupts/timers_interrupts\\.c$")
list(FILTER FW_SOURCES EXCLUDE REGEX "/src/OSLikeStuff/fault_handler/")
list(FILTER FW_SOURCES EXCLUDE REGEX "/src/deluge/memory/(general_memory_allocator|memory_region)\\.cpp$")
# NE10: the C sources its own CMakeLists lists (its .s files are ARMv7-only headers).
file(READ "${FW}/src/NE10/CMakeLists.txt" ne10_cmake)
string(REGEX MATCHALL "[A-Za-z0-9_/.]+\\.(cpp|c)" NE10_REL "${ne10_cmake}")
set(NE10_SOURCES "")
foreach(f ${NE10_REL})
  list(APPEND NE10_SOURCES "${FW}/src/NE10/${f}")
endforeach()

set(PLATFORM_SOURCES
  engine/platform/host_memory.c
  engine/platform/host_gma.cpp
  engine/platform/host_freeze.cpp
  engine/platform/host_startup.cpp
  engine/platform/hw_stubs.cpp
  engine/platform/usb_stubs.c
  engine/platform/host_diskio.cpp
  engine/platform/card_image.cpp
  engine/platform/host_fm_kernel.c
  engine/platform/host_testport.cpp)

# ---- Flags. The firmware's own (src/CMakeLists.txt's add_compile_options), plus the Engine's (spec §3.3):
# the test port in every build, no fused multiply-add, and DELUGE_HOST for the host seams (S4). Everything that
# includes firmware headers (firmware, engine/platform, front ends) gets these through the firmware target.
set(FW_DEFINES ENABLE_SYSEX_TEST=1 DELUGE_HOST=1 USE_TASK_MANAGER _GNU_SOURCE)
set(FW_FLAGS
  -ffast-math -fsigned-char -ffp-contract=off
  "$<$<COMPILE_LANGUAGE:CXX>:-fno-rtti;-fno-threadsafe-statics>"
  -include "${CMAKE_CURRENT_SOURCE_DIR}/engine/platform/host_prefix.h")
# A pointer truncation must fail the build (seam S1; no -fms-extensions). In C++ clang already makes those errors;
# these make the C ones errors too.
set(CAST_ERRORS -Werror=pointer-to-int-cast -Werror=int-to-pointer-cast
  -Werror=void-pointer-to-int-cast -Werror=int-to-void-pointer-cast)
# The firmware's own cpu_specific.h must stay a no-op behind the host one (host_prefix.h): if its body were ever
# read, its UNCACHED_MIRROR_OFFSET would redefine the host's. Clang applies warning flags in order, so this must come
# after -Wno-everything to survive it.
set(GUARD_ERRORS -Werror=macro-redefined)
# Warnings in firmware sources aren't ours to fix here: off for the firmware target only, except the guard and cast
# errors, which come after -Wno-everything.
set(FW_PRIVATE_FLAGS -Wno-everything ${GUARD_ERRORS} ${CAST_ERRORS})
# The Engine's own code keeps its warnings. Firmware headers count as system headers there (firmware's SYSTEM).
set(ENGINE_WARNINGS -Wall -Wextra -Wno-unused-parameter -Wno-overriding-option ${GUARD_ERRORS} ${CAST_ERRORS})
set(FW_INCLUDES
  "${GEN}/host"             # generated RZ/A1 headers win over the firmware's
  "${CMAKE_CURRENT_SOURCE_DIR}/engine/platform"
  "${GEN}"                  # version.h, util/firmware_version.h, version.cpp.gen
  "${FW}/src/OSLikeStuff"
  "${FW}/src"
  "${FW}/src/deluge"
  "${FW}/src/fatfs"
  "${FW}/src/NE10/inc"
  "${FW}/src/NE10/common"
  "${FW}/src/NE10/modules"
  "${FW}/src/lib")

if(DELUGE_SANITIZE)
  # Spec §11: the sanitizer build is -O1, with every ASan and UBSan check on everywhere; a UB report stops the run
  # instead of scrolling past. ubsan_ignorelist.txt exempts single firmware files from single checks, each with its
  # reason there and in docs/implementation-notes.md.
  set(SAN_FLAGS -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=undefined
      "-fsanitize-ignorelist=${CMAKE_CURRENT_SOURCE_DIR}/engine/platform/ubsan_ignorelist.txt")
endif()

add_library(firmware OBJECT ${FW_SOURCES} ${NE10_SOURCES})
add_dependencies(firmware host_headers)
set_target_properties(firmware PROPERTIES C_STANDARD 23 C_EXTENSIONS ON CXX_STANDARD 23 CXX_EXTENSIONS ON
  SYSTEM ON)
target_compile_definitions(firmware PUBLIC ${FW_DEFINES})
target_compile_options(firmware PUBLIC ${FW_FLAGS} ${SAN_FLAGS} PRIVATE ${FW_PRIVATE_FLAGS})
target_include_directories(firmware PUBLIC ${FW_INCLUDES})
target_link_libraries(firmware PUBLIC argon etl::etl)

# The hardware stand-ins (spec §3.5).
add_library(engine_platform OBJECT ${PLATFORM_SOURCES})
set_target_properties(engine_platform PROPERTIES C_STANDARD 23 C_EXTENSIONS ON CXX_STANDARD 23 CXX_EXTENSIONS ON)
target_include_directories(engine_platform PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/engine")
target_link_libraries(engine_platform PUBLIC firmware)
target_compile_options(engine_platform PRIVATE ${ENGINE_WARNINGS})

# ---- The first render: one preset and one note to a WAV. E4 replaces it with `deluge-engine render`.
add_executable(render_preset engine/cli/render_preset.cpp)
set_target_properties(render_preset PROPERTIES CXX_STANDARD 23 CXX_EXTENSIONS ON)
target_link_libraries(render_preset PRIVATE engine_platform firmware)
target_compile_options(render_preset PRIVATE ${ENGINE_WARNINGS})
target_link_options(render_preset PRIVATE -Wl,-dead_strip ${SAN_FLAGS})

# ---- Platform-layer unit tests (E2, spec §3.4 & §3.5).
add_executable(test_platform tests/platform/test_platform.cpp)
set_target_properties(test_platform PROPERTIES CXX_STANDARD 23 CXX_EXTENSIONS ON)
target_link_libraries(test_platform PRIVATE engine_platform firmware)
target_compile_options(test_platform PRIVATE ${ENGINE_WARNINGS})
target_link_options(test_platform PRIVATE -Wl,-dead_strip ${SAN_FLAGS})

# ---- Card-image & storage unit tests (E3, spec §3.6).
add_executable(test_storage tests/storage/test_storage.cpp)
set_target_properties(test_storage PROPERTIES CXX_STANDARD 23 CXX_EXTENSIONS ON)
target_link_libraries(test_storage PRIVATE engine_platform firmware)
target_compile_options(test_storage PRIVATE ${ENGINE_WARNINGS})
target_link_options(test_storage PRIVATE -Wl,-dead_strip ${SAN_FLAGS})
