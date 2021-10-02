# Copyright (c) .NET Foundation and contributors. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

# Verify minimum required version
cmake_minimum_required(VERSION 3.6.2)

if(CMAKE_VERSION VERSION_EQUAL 3.0 OR CMAKE_VERSION VERSION_GREATER 3.0)
  cmake_policy(SET CMP0042 NEW)
endif()

# Set the project name
project(diagnostics)

# include shared compiler configs
include(eng/native/configurepaths.cmake)
include(${CLR_ENG_NATIVE_DIR}/configurecompiler.cmake)

# override some global configs
if (NOT WIN32)
  add_compile_options(-Wno-unused-parameter)
  add_compile_options(-Wno-unused-variable)
  add_compile_options(-Wno-implicit-fallthrough)
endif (NOT WIN32)

# Register the default component
set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME diagnostics)
add_component(diagnostics)

if (WIN32)
  message(STATUS "VS_PLATFORM_TOOLSET is ${CMAKE_VS_PLATFORM_TOOLSET}")
  message(STATUS "VS_PLATFORM_NAME is ${CMAKE_VS_PLATFORM_NAME}")
endif (WIN32)

set(ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

# Where the version source file for xplat is generated
set(VERSION_FILE_PATH "${CMAKE_BINARY_DIR}/version.cpp")

# Where _version.h for Windows is generated
if (WIN32)
include_directories("${CMAKE_BINARY_DIR}")
endif (WIN32)

#--------------------------------------
# FEATURE Defines
#--------------------------------------

add_definitions(-DFEATURE_CORESYSTEM)

if(CLR_CMAKE_PLATFORM_UNIX)
    add_definitions(-DFEATURE_PAL)
    add_definitions(-DFEATURE_PAL_ANSI)
endif(CLR_CMAKE_PLATFORM_UNIX)

if(WIN32)
    add_definitions(-DFEATURE_COMINTEROP)
endif(WIN32)

if(NOT CMAKE_SYSTEM_NAME STREQUAL NetBSD)
    add_definitions(-DFEATURE_HIJACK)
endif(NOT CMAKE_SYSTEM_NAME STREQUAL NetBSD)

if(FEATURE_EVENT_TRACE)
    add_definitions(-DFEATURE_EVENT_TRACE=1)
    add_definitions(-DFEATURE_PERFTRACING=1)
endif(FEATURE_EVENT_TRACE)

if(CLR_CMAKE_PLATFORM_UNIX_AMD64)
    add_definitions(-DFEATURE_MULTIREG_RETURN)
endif (CLR_CMAKE_PLATFORM_UNIX_AMD64)

if(CLR_CMAKE_PLATFORM_UNIX AND CLR_CMAKE_TARGET_ARCH_AMD64)
    add_definitions(-DUNIX_AMD64_ABI)
endif(CLR_CMAKE_PLATFORM_UNIX AND CLR_CMAKE_TARGET_ARCH_AMD64)

#--------------------------------------
# Compile Options
#--------------------------------------
include(compileoptions.cmake)

#-----------------------------------------
# Native Projects
#-----------------------------------------
add_subdirectory(src)
