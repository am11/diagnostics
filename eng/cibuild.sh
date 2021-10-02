#!/usr/bin/env bash
# Copyright (c) .NET Foundation and contributors. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

source="${BASH_SOURCE[0]}"

# resolve $SOURCE until the file is no longer a symlink
while [[ -h $source ]]; do
  scriptroot="$( cd -P "$( dirname "$source" )" && pwd )"
  source="$(readlink "$source")"

  # if $source was a relative symlink, we need to resolve it relative to the path where 
  # the symlink file was located
  [[ $source != /* ]] && source="$scriptroot/$source"
done

scriptroot="$( cd -P "$( dirname "$source" )" && pwd )"

# Fix any CI lab docker image problems

__osname=$(uname -s)
if [ "$__osname" == "Linux" ]; then
    if [ -e /etc/os-release ]; then
        source /etc/os-release
        if [[ $ID == "ubuntu" ]]; then
            if [[ $VERSION_ID == "18.04" ]]; then
                # Fix the CI lab's ubuntu 18.04 docker image: install curl.
                sudo apt-get update
                sudo apt-get install -y curl
            fi
        fi
    elif [ -e /etc/redhat-release ]; then
        __redhatRelease=$(</etc/redhat-release)
        if [[ $__redhatRelease == "CentOS release 6."* || $__redhatRelease == "Red Hat Enterprise Linux Server release 6."* ]]; then
            source scl_source enable python27 devtoolset-2
        fi
    fi

    # We are running old (2019) centos image in CI in diagnostics repo. using 2021 image was failing SOS tests
    # which rely on lldb REPL and ptrace etc. From test attachment logs:
    #             00:00.136: error: process launch failed: 'A' packet returned an error: 8
    #             00:00.136:
    #             00:00.136: <END_COMMAND_ERROR>
    #System.Exception: 'process launch -s' FAILED
    #
    # so we upgrade cmake in-place as a workaround..
    # FIXME: delete this comment and the next `if` block once centos image is upgraded.
    if [ "$ID" = "centos" ]; then
        # upgrade cmake
        requiredversion=3.6.2
        cmakeversion="$(cmake --version)"
        currentversion="${cmakeversion##* }"
        if ! printf '%s\n' "$requiredversion" "$currentversion" | sort --version-sort --check 2>/dev/null; then
            echo "Old cmake version found: $currentversion, minimal requirement is 3.6.2. Upgrading to 3.15.5"
            curl -SL -o cmake-install.sh https://github.com/Kitware/CMake/releases/download/v3.15.5/cmake-3.15.5-Linux-$(uname -m).sh
            bash ./cmake-install.sh --skip-license --exclude-subdir --prefix=/usr/local
            rm ./cmake-install.sh
            cmakeversion="$(cmake --version)"
            newversion="${cmakeversion##* }"
            echo "New cmake version is: $cmakeversion"
       fi
    fi
fi

"$scriptroot/build.sh" --restore --prepareMachine --ci --stripsymbols $@
if [[ $? != 0 ]]; then
    exit 1
fi
