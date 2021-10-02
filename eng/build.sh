#!/usr/bin/env bash
# Copyright (c) .NET Foundation and contributors. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

# Obtain the location of the bash script to figure out where the root of the repo is.
__RepoRootDir="$(cd "$(dirname "$0")"/..; pwd -P)"

__TargetOS=Linux
__HostOS=Linux
__BuildArch=x64
__HostArch=x64
__BuildType=Debug
__PortableBuild=1
__ExtraCmakeArgs=
__Compiler=clang
__CompilerMajorVersion=
__CompilerMinorVersion=
__NumProc=1
__ManagedBuild=1
__NativeBuild=1
__CrossBuild=false
__Test=false
__PrivateBuildPath=
__TestArgs=
__UnprocessedBuildArgs=
__CommonMSBuildArgs=
__DotnetRuntimeVersion="default"
__DotnetRuntimeDownloadVersion="default"
__RuntimeSourceFeed=
__RuntimeSourceFeedKey=
__SkipConfigure=0

usage_list+=("-skipmanaged: do not build managed components.")
usage_list+=("-skipnative: do not build native components.")
usage_list+=("-privatebuildpath: path to local private runtime build to test.")
usage_list+=("-test: run xunit tests")

handle_arguments() {

    case "$1" in
        configuration|-c)
            if [[ "$2" == "release" ]]; then
                __BuildType=Release
            elif [[ "$2" = "checked" ]]; then
                __BuildType=Checked
            fi

            __ShiftArgs=1
            ;;

        privatebuildpath|-privatebuildpath)
            __PrivateBuildPath="$1"
            ;;

        skipmanaged|-skipmanaged)
            __ManagedBuild=0
            ;;

        skipnative|-skipnative)
            __NativeBuild=0
            ;;

        test|-test)
            __Test=true
            ;;

        *)
            __UnprocessedBuildArgs="$__UnprocessedBuildArgs $1"
            ;;
    esac
}

source "$__RepoRootDir"/eng/native/build-commons.sh

__RootBinDir="$__RepoRootDir"/artifacts
__BinDir="$__RootBinDir/bin/$__TargetOS.$__BuildArch.$__BuildType"
__LogDir="$__RootBinDir/log/$__TargetOS.$__BuildArch.$__BuildType"
__IntermediatesDir="$__RootBinDir/obj/$__TargetOS.$__BuildArch.$__BuildType"
__ExtraCmakeArgs="$__ExtraCmakeArgs -DCLR_MANAGED_BINARY_DIR=$__RootBinDir/bin -DCLR_BUILD_TYPE=$__BuildType"
__DotNetCli="$__RepoRootDir"/.dotnet/dotnet

# Specify path to be set for CMAKE_INSTALL_PREFIX.
# This is where all built native libraries will copied to.
export __CMakeBinDir="$__BinDir"


if [[ "$__BuildArch" == "armel" ]]; then
    # Armel cross build is Tizen specific and does not support Portable RID build
    __PortableBuild=0
fi

#
# Managed build
#

if [[ "$__ManagedBuild" == 1 ]]; then
    echo "Commencing managed build for $__BuildType in $__RootBinDir/bin"
    "$__RepoRootDir/eng/common/build.sh" --build --configuration "$__BuildType" $__CommonMSBuildArgs $__UnprocessedBuildArgs
    if [ "$?" != 0 ]; then
        exit 1
    fi
fi

#
# Initialize the target distro name
#

initTargetDistroRid

echo "RID: $__DistroRid"

#
# Setup LLDB paths for native build
#

if [ "$__HostOS" == "OSX" ]; then
    export LLDB_H="$__RepoRootDir"/src/SOS/lldbplugin/swift-4.0
    export LLDB_LIB=$(xcode-select -p)/../SharedFrameworks/LLDB.framework/LLDB
    export LLDB_PATH=$(xcode-select -p)/usr/bin/lldb

    export MACOSX_DEPLOYMENT_TARGET=10.12

    if [ ! -f $LLDB_LIB ]; then
        echo "Cannot find the lldb library. Try installing Xcode."
        exit 1
    fi

    # Workaround bad python version in /usr/local/bin/python2.7 on lab machines
    export PATH=/usr/bin:$PATH
    which python
    python --version

    if [[ "$__BuildArch" == x64 ]]; then
        __ExtraCmakeArgs="-DCMAKE_OSX_ARCHITECTURES=\"x86_64\" $__ExtraCmakeArgs"
    elif [[ "$__BuildArch" == arm64 ]]; then
        __ExtraCmakeArgs="-DCMAKE_OSX_ARCHITECTURES=\"arm64\" $__ExtraCmakeArgs"
    else
        echo "Error: Unknown OSX architecture $__BuildArch."
        exit 1
    fi
fi

#
# Build native components
#

if [ ! -e $__DotNetCli ]; then
   echo "dotnet cli not installed $__DotNetCli"
   exit 1
fi

mkdir -p "$__IntermediatesDir"
mkdir -p "$__LogDir"
mkdir -p "$__CMakeBinDir"

if [[ "$__NativeBuild" == 1 ]]; then
    build_native "$__TargetOS" "$__BuildArch" "$__RepoRootDir" "$__IntermediatesDir" "install" "$__ExtraCmakeArgs" "diagnostic component"
fi

#
# Copy the native SOS binaries to where these tools expect for testing
#

if [[ "$__NativeBuild" == 1 || "$__Test" == 1 ]]; then
    __dotnet_sos=$__RootBinDir/bin/dotnet-sos/$__BuildType/netcoreapp3.1/publish/$__DistroRid
    __dotnet_dump=$__RootBinDir/bin/dotnet-dump/$__BuildType/netcoreapp3.1/publish/$__DistroRid

    mkdir -p "$__dotnet_sos"
    mkdir -p "$__dotnet_dump"

    cp "$__BinDir"/* "$__dotnet_sos"
    echo "Copied SOS to $__dotnet_sos"

    cp "$__BinDir"/* "$__dotnet_dump"
    echo "Copied SOS to $__dotnet_dump"
fi

#
# Run xunit tests
#

if [ $__Test == true ]; then
   if [ $__CrossBuild != true ]; then
      if [ "$LLDB_PATH" == "" ]; then
          export LLDB_PATH="$(which lldb-3.9.1 2> /dev/null)"
          if [ "$LLDB_PATH" == "" ]; then
              export LLDB_PATH="$(which lldb-3.9 2> /dev/null)"
              if [ "$LLDB_PATH" == "" ]; then
                  export LLDB_PATH="$(which lldb-4.0 2> /dev/null)"
                  if [ "$LLDB_PATH" == "" ]; then
                      export LLDB_PATH="$(which lldb-5.0 2> /dev/null)"
                      if [ "$LLDB_PATH" == "" ]; then
                          export LLDB_PATH="$(which lldb 2> /dev/null)"
                      fi
                  fi
              fi
          fi
      fi

      if [ "$GDB_PATH" == "" ]; then
          export GDB_PATH="$(which gdb 2> /dev/null)"
      fi

      echo "lldb: '$LLDB_PATH' gdb: '$GDB_PATH'"

      "$__RepoRootDir/eng/common/build.sh" \
        --test \
        --configuration "$__BuildType" \
        /bl:$__LogDir/Test.binlog \
        /p:BuildArch="$__BuildArch" \
        /p:PrivateBuildPath="$__PrivateBuildPath" \
        /p:DotnetRuntimeVersion="$__DotnetRuntimeVersion" \
        /p:DotnetRuntimeDownloadVersion="$__DotnetRuntimeDownloadVersion" \
        /p:RuntimeSourceFeed="$__RuntimeSourceFeed" \
        /p:RuntimeSourceFeedKey="$__RuntimeSourceFeedKey" \
        $__CommonMSBuildArgs \
        $__TestArgs

      if [ $? != 0 ]; then
          exit 1
      fi
   fi
fi

echo "BUILD: Repo sucessfully built."
echo "BUILD: Product binaries are available at $__CMakeBinDir"
