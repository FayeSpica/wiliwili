cmake_minimum_required(VERSION 3.6)

project(WILIWILI_ANDROID)

# armeabi-v7a requires cpufeatures library
# include(AndroidNdkModules)
# android_ndk_import_module_cpufeatures()

set(BUILD_SHARED_LIBS ON CACHE BOOL "")

# SDL sources are in a subfolder named "SDL"
# NDK 29+ marks ALooper_pollAll as obsoleted, SDL 2.28 still uses it.
# Patch the file before building SDL.
execute_process(
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${CMAKE_CURRENT_SOURCE_DIR}/patches/SDL_androidsensor.c
    ${CMAKE_CURRENT_SOURCE_DIR}/SDL/src/sensor/android/SDL_androidsensor.c
)

add_subdirectory(SDL)

# Set platform flags
SET(PLATFORM_ANDROID ON CACHE BOOL "")
SET(USE_SDL2 ON CACHE BOOL "")
SET(LIBROMFS_PREBUILT_GENERATOR "${CMAKE_CURRENT_SOURCE_DIR}/borealis/libromfs-generator" CACHE STRING "")

if (NOT EXISTS "${LIBROMFS_PREBUILT_GENERATOR}")
    message(FATAL_ERROR "libromfs-generator has not been built, please refer to borealis/build_libromfs_generator.sh for more information")
endif()

# wiliwili project root (4 levels up from scripts/android/app/jni/)
set(WILIWILI_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../)

# Set wiliwili resources dir for libromfs
set(BRLS_RESOURCES_DIR ".")

# mpv related options - Android uses shared libmpv
option(MPV_SW_RENDER "Using CPU to draw videos" OFF)
option(MPV_NO_FB "Using system provided framebuffer" OFF)

# Disable OpenCC on Android (uses libromfs, no filesystem access to dict files)
set(DISABLE_OPENCC ON CACHE BOOL "" FORCE)

# Disable webp by default on Android
set(DISABLE_WEBP ON CACHE BOOL "" FORCE)

# Ensure BRLS_UNITY_BUILD is set (required for set_target_properties)
set(BRLS_UNITY_BUILD OFF CACHE BOOL "" FORCE)

# Include borealis common options and toolchain
include(${CMAKE_CURRENT_SOURCE_DIR}/borealis/cmake/commonOption.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/borealis/cmake/toolchain.cmake)

# Configure libromfs with wiliwili resources (after toolchain sets USE_LIBROMFS)
add_libromfs(wiliwili ${WILIWILI_ROOT}/resources)

# Add borealis
add_subdirectory(borealis)

# Fix fseeko issue on 32-bit Android (not available before API 24)
set(HAVE_FSEEKO 0 CACHE STRING "" FORCE)

# Add wiliwili third-party libraries
# cpr - use bundled OpenSSL for Android
set(CPR_USE_SYSTEM_CURL OFF)
set(CPR_ENABLE_SSL ON)
set(CPR_FORCE_OPENSSL_BACKEND ON)

# Point curl/cpr to our prebuilt OpenSSL
set(OPENSSL_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/openssl-android CACHE PATH "" FORCE)
set(OPENSSL_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/openssl-android/include CACHE PATH "" FORCE)
set(OPENSSL_SSL_LIBRARY ${CMAKE_CURRENT_SOURCE_DIR}/openssl-android/lib/${ANDROID_ABI}/libssl.a CACHE FILEPATH "" FORCE)
set(OPENSSL_CRYPTO_LIBRARY ${CMAKE_CURRENT_SOURCE_DIR}/openssl-android/lib/${ANDROID_ABI}/libcrypto.a CACHE FILEPATH "" FORCE)
set(OPENSSL_FOUND TRUE CACHE BOOL "" FORCE)

# Set CA cert path for Android
set(CURL_CA_PATH "/system/etc/security/cacerts" CACHE STRING "" FORCE)
set(CURL_CA_BUNDLE "none" CACHE STRING "" FORCE)

set(BUILD_SHARED_LIBS OFF)
add_subdirectory(${WILIWILI_ROOT}/library/cpr cpr EXCLUDE_FROM_ALL)

# QR-Code-generator
add_library(qrcode STATIC ${WILIWILI_ROOT}/library/QR-Code-generator/cpp/qrcodegen.cpp)
target_include_directories(qrcode PUBLIC ${WILIWILI_ROOT}/library/QR-Code-generator/cpp)
set_property(TARGET qrcode PROPERTY CXX_STANDARD 17)

# pystring
add_library(pystring STATIC ${WILIWILI_ROOT}/library/pystring/pystring.cpp)
target_include_directories(pystring PUBLIC ${WILIWILI_ROOT}/library/pystring)
set_property(TARGET pystring PROPERTY CXX_STANDARD 17)

# lunasvg
set(BUILD_SHARED_LIBS OFF)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
add_subdirectory(${WILIWILI_ROOT}/library/lunasvg lunasvg EXCLUDE_FROM_ALL)

# mongoose
set(MG_ENABLE_IPV6 ON)
add_subdirectory(${WILIWILI_ROOT}/library/mongoose mongoose EXCLUDE_FROM_ALL)

# libpdr
file(GLOB_RECURSE PDR_SRC ${WILIWILI_ROOT}/library/libpdr/src/*.cpp)
add_library(pdr ${PDR_SRC})
set_property(TARGET pdr PROPERTY CXX_STANDARD 17)
target_include_directories(pdr PUBLIC ${WILIWILI_ROOT}/library/libpdr/include)
target_link_libraries(pdr mongoose tinyxml2)

add_library(wiliwiliLibExtra INTERFACE)
target_link_libraries(wiliwiliLibExtra INTERFACE cpr::cpr qrcode)

# wiliwili source files
file(GLOB_RECURSE MAIN_SRC ${WILIWILI_ROOT}/wiliwili/source/*.cpp)

# nanovg
add_definitions(-DFONS_HASH_LUT_SIZE=4096)

# Git info placeholders for Android build
set(GIT_TAG_VERSION "v1.5.3")
set(GIT_TAG_SHORT "unknown")

# Build version info
set(VERSION_MAJOR "1")
set(VERSION_MINOR "5")
set(VERSION_REVISION "3")
set(VERSION_BUILD "0")
set(PACKAGE_NAME cn.xfangfang.wiliwili)

# mpv library for Android (prebuilt shared library from mpv-android)
add_library(mpv SHARED IMPORTED)
set_target_properties(mpv PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../libs/${ANDROID_ABI}/libmpv.so
    INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/mpv-android/include
)

# Main target - shared library for Android
add_library(wiliwili SHARED ${MAIN_SRC})
set_target_properties(wiliwili PROPERTIES CXX_STANDARD 17)

target_include_directories(wiliwili PRIVATE
    ${WILIWILI_ROOT}/wiliwili/include
    ${WILIWILI_ROOT}/wiliwili/include/api
    ${CMAKE_CURRENT_SOURCE_DIR}/mpv-android/include
)

target_compile_options(wiliwili PRIVATE
    -ffunction-sections -fdata-sections -Wunused-variable
    -DBUILD_TAG_VERSION=${GIT_TAG_VERSION}
    -DBUILD_TAG_SHORT=${GIT_TAG_SHORT}
    -DBUILD_PACKAGE_NAME=${PACKAGE_NAME}
    -DBUILD_VERSION_MAJOR=${VERSION_MAJOR}
    -DBUILD_VERSION_MINOR=${VERSION_MINOR}
    -DBUILD_VERSION_REVISION=${VERSION_REVISION}
)

target_link_libraries(wiliwili PRIVATE
    wiliwiliLibExtra
    borealis
    lunasvg
    pystring
    pdr
    mongoose
    mpv
    z
    SDL2
)
