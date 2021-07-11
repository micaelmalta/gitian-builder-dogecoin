#!/bin/bash

# Copyright (c) 2016 The Bitcoin Core developers
# Copyright (c) 2021 The Dogecoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

# GITIAN PROPERTIES
unset USE_LXC
unset USE_VBOX
export USE_DOCKER=1

# What to do
sign=false
verify=false
build=false
commit=false
push=false
init=false

# Systems to build
linux=true
windows=true
osx=true

# Other Basic variables
SIGNER=
VERSION=
url=https://github.com/dogecoin/dogecoin
proc=2
mem=2000
scriptName=$(basename -- "$0")
commitFiles=true

# Help Message
read -d '' usage <<-EOF
Usage: $scriptName [-c|u|v|b|s|B|o|h|j|m|] signer version
Run this script from the directory containing the dogecoin, gitian-builder, gitian.sigs, and dogecoin-detached-sigs.
Arguments:
signer          GPG signer to sign each build assert file
version		Version number, commit, or branch to build. If building a commit or branch, the -c option must be specified
Options:
-c|--commit	Indicate that the version argument is for a commit or branch
-u|--url	Specify the URL of the repository. Default is https://github.com/dogecoin/dogecoin
-v|--verify 	Verify the gitian build
-b|--build	Do a gitian build
-s|--sign	Make signed binaries for Windows and Mac OSX
-B|--buildsign	Build both signed and unsigned binaries
-o|--os		Specify which Operating Systems the build is for. Default is lwx. l for linux, w for windows, x for osx
-j		Number of processes to use. Default 2
-m		Memory to allocate in MiB. Default 2000
--setup         Setup the gitian building environment. Uses Docker.
--detach-sign   Create the assert file for detached signing. Will not commit anything.
--no-commit     Do not commit anything to git
-h|--help	Print this help message
EOF

# Get options and arguments
while :; do
  case $1 in
  # Verify
  -v | --verify)
    verify=true
    ;;
  # Build
  -b | --build)
    build=true
    ;;
  # Build
  -p | --push)
    push=true
    ;;
  # Sign binaries
  -s | --sign)
    sign=true
    ;;
  # Build then Sign
  -B | --buildsign)
    sign=true
    build=true
    ;;
  # PGP Signer
  -S | --signer)
    if [ -n "$2" ]; then
      SIGNER=$2
      shift
    else
      echo 'Error: "--signer" requires a non-empty argument.'
      exit 1
    fi
    ;;
  # Operating Systems
  -o | --os)
    if [ -n "$2" ]; then
      linux=false
      windows=false
      osx=false
      if [[ "$2" == *"l"* ]]; then
        linux=true
      fi
      if [[ "$2" == *"w"* ]]; then
        windows=true
      fi
      if [[ "$2" == *"x"* ]]; then
        osx=true
      fi
      shift
    else
      echo 'Error: "--os" requires an argument containing an l (for linux), w (for windows), or x (for Mac OSX)\n'
      exit 1
    fi
    ;;
  # Help message
  -h | --help)
    echo "$usage"
    exit 0
    ;;
  # Commit or branch
  -c | --commit)
    commit=true
    ;;
  # Init dependencies
  -i | --init)
    init=true
    ;;
  # Number of Processes
  -j)
    if [ -n "$2" ]; then
      proc=$2
      shift
    else
      echo 'Error: "-j" requires an argument'
      exit 1
    fi
    ;;
  # Memory to allocate
  -m)
    if [ -n "$2" ]; then
      mem=$2
      shift
    else
      echo 'Error: "-m" requires an argument'
      exit 1
    fi
    ;;
  # URL
  -u)
    if [ -n "$2" ]; then
      url=$2
      shift
    else
      echo 'Error: "-u" requires an argument'
      exit 1
    fi
    ;;
  # Detach sign
  --detach-sign)
    commitFiles=false
    ;;
  # Commit files
  --no-commit)
    commitFiles=false
    ;;
  # Setup
  --setup)
    setup=true
    ;;
  *) # Default case: If no more options then break out of the loop.
    break ;;
  esac
  shift
done

echo "Using ${proc} CPU and ${mem} RAM"

# Get signer
if [[ -n "$1" ]]; then
  SIGNER=$1
  shift
fi

# Get version
if [[ -n "$1" ]]; then
  VERSION=$1
  COMMIT=$VERSION
  shift
fi

if [[ ! $setup == true && ! $push == true && ! $init == true ]]; then
  echo "Testing Docker..."
  if ! docker ps &>/dev/null; then
    echo "Docker is not launched..."
    exit 1
  fi

  echo "Testing GPG Keys available..."
  result=$(gpg --list-secret-keys --keyid-format=long | grep sec | grep -v revoked | grep "" -c)
  if [[ $result == "" ]]; then
    echo "No GPG keys available..."
    echo "Please follow this documentation: https://docs.github.com/en/github/authenticating-to-github/managing-commit-signature-verification/generating-a-new-gpg-key"
    exit 1
  fi

  echo ${COMMIT}
  # Check that a signer is specified
  if [[ $SIGNER == "" ]]; then
    echo "$scriptName: Missing signer."
    echo "Try $scriptName --help for more information"
    exit 1
  fi

  # Check that a version is specified
  if [[ $VERSION == "" ]]; then
    echo "$scriptName: Missing version."
    echo "Try $scriptName --help for more information"
    exit 1
  fi
fi

# Add a "v" if no -c
if [[ $commit == false ]]; then
  COMMIT="v${VERSION}"
fi

# Setup build environment
if [[ $init == true ]]; then
  echo "Setup Dependencies..."

  ./setup/setup.sh
  exit
fi

# Setup build environment
if [[ $setup == true ]]; then
  git clone https://github.com/micaelmalta/gitian-builder
  pushd gitian-builder
  git fetch
  git checkout docker
  git reset --hard origin/docker
  popd
  git clone https://github.com/dogecoin/gitian.sigs.git
  git clone https://github.com/dogecoin/dogecoin-detached-sigs.git
  git clone $url

  docker build --pull -f apt_cacher_ng.Dockerfile -t apt_cacher_ng .
  docker run -d -p 3142:3142 --name apt_cacher_ng apt_cacher_ng

  pushd gitian-builder
  export MIRROR_HOST=127.0.0.1
   ./bin/make-base-vm --docker --arch amd64 --suite trusty
  ../setup/dependencies.sh
  popd
  exit

fi

# Build
if [[ $build == true ]]; then
  # Check for OSX SDK
  if [[ ! -e "gitian-builder/inputs/MacOSX10.11.sdk.tar.gz" && $osx == true ]]; then
    echo "Cannot build for OSX, SDK does not exist. Will build for other OSes"
    osx=false
  fi

  # Set up build
  pushd ./dogecoin
  git remote set-url origin $url
  git fetch
  git checkout ${COMMIT}
  git reset --hard origin/${COMMIT}
  popd

  # Make output folder
  mkdir -p ./dogecoin-binaries/${VERSION}

  pushd ./gitian-builder

  make -j "${proc}" -C ../dogecoin/depends download SOURCES_PATH=$(pwd)/cache/common

  # Linux
  if [[ $linux == true ]]; then
    echo ""
    echo "Compiling ${VERSION} Linux"
    echo ""
    ./bin/gbuild -j ${proc} -m ${mem} --commit dogecoin=${COMMIT} --url dogecoin=${url} ../dogecoin/contrib/gitian-descriptors/gitian-linux.yml
  fi
  # Windows
  if [[ $windows == true ]]; then
    echo ""
    echo "Compiling ${VERSION} Windows"
    echo ""
    ./bin/gbuild -j ${proc} -m ${mem} --commit dogecoin=${COMMIT} --url dogecoin=${url} ../dogecoin/contrib/gitian-descriptors/gitian-win.yml
  fi
  # Mac OSX
  if [[ $osx == true ]]; then
    echo ""
    echo "Compiling ${VERSION} Mac OSX"
    echo ""
    ./bin/gbuild -j ${proc} -m ${mem} --commit dogecoin=${COMMIT} --url dogecoin=${url} ../dogecoin/contrib/gitian-descriptors/gitian-osx.yml
  fi
  popd

  if [[ $commitFiles == true ]]; then
    # Commit to gitian.sigs repo
    echo ""
    echo "Committing ${VERSION} Unsigned Sigs"
    echo ""
    pushd gitian.sigs
    git add ${VERSION}-linux/${SIGNER}
    git add ${VERSION}-win-unsigned/${SIGNER}
    git add ${VERSION}-osx-unsigned/${SIGNER}
    git commit -a -m "Add ${VERSION} unsigned sigs for ${SIGNER}"
    popd
  fi
fi

# Verify the build
if [[ $verify == true ]]; then
  # Linux
  pushd ./gitian-builder
  echo ""
  echo "Verifying v${VERSION} Linux"
  echo ""
  ./bin/gverify -v -d ../gitian.sigs/ -r ${VERSION}-linux ../dogecoin/contrib/gitian-descriptors/gitian-linux.yml
  # Windows
  echo ""
  echo "Verifying v${VERSION} Windows"
  echo ""
  ./bin/gverify -v -d ../gitian.sigs/ -r ${VERSION}-win-unsigned ../dogecoin/contrib/gitian-descriptors/gitian-win.yml
  # Mac OSX
  echo ""
  echo "Verifying v${VERSION} Mac OSX"
  echo ""
  ./bin/gverify -v -d ../gitian.sigs/ -r ${VERSION}-osx-unsigned ../dogecoin/contrib/gitian-descriptors/gitian-osx.yml
  #	# Signed Windows
  #	echo ""
  #	echo "Verifying v${VERSION} Signed Windows"
  #	echo ""
  #	./bin/gverify -v -d ../gitian.sigs/ -r ${VERSION}-osx-signed ../dogecoin/contrib/gitian-descriptors/gitian-osx-signer.yml
  #	# Signed Mac OSX
  #	echo ""
  #	echo "Verifying v${VERSION} Signed Mac OSX"
  #	echo ""
  #	./bin/gverify -v -d ../gitian.sigs/ -r ${VERSION}-osx-signed ../dogecoin/contrib/gitian-descriptors/gitian-osx-signer.yml
  popd
fi

if [[ $sign == true ]]; then
  if [[ $linux == true ]]; then
    ./bin/gsign --signer $SIGNER --release ${VERSION}-linux --destination ../gitian.sigs/ ../dogecoin/contrib/gitian-descriptors/gitian-linux.yml
    mv build/out/dogecoin-*.tar.gz build/out/src/dogecoin-*.tar.gz ../dogecoin-binaries/${VERSION}
  fi

  if [[ $windows == true ]]; then
    ./bin/gsign --signer $SIGNER --release ${VERSION}-win-unsigned --destination ../gitian.sigs/ ../dogecoin/contrib/gitian-descriptors/gitian-win.yml
    mv build/out/dogecoin-*-win-unsigned.tar.gz inputs/dogecoin-win-unsigned.tar.gz
    mv build/out/dogecoin-*.zip build/out/dogecoin-*.exe ../dogecoin-binaries/${VERSION}
  fi

  if [[ $osx == true ]]; then
    ./bin/gsign --signer $SIGNER --release ${VERSION}-osx-unsigned --destination ../gitian.sigs/ ../dogecoin/contrib/gitian-descriptors/gitian-osx.yml
    mv build/out/dogecoin-*-osx-unsigned.tar.gz inputs/dogecoin-osx-unsigned.tar.gz
    mv build/out/dogecoin-*.tar.gz build/out/dogecoin-*.dmg ../dogecoin-binaries/${VERSION}
  fi
fi

# Sign binaries
#if [[ $sign = true ]]
#then
#
#  pushd ./gitian-builder
#	# Sign Windows
#	if [[ $windows = true ]]
#	then
#	    echo ""
#	    echo "Signing ${VERSION} Windows"
#	    echo ""
#	    ./bin/gbuild -i --commit signature=${COMMIT} ../dogecoin/contrib/gitian-descriptors/gitian-win-signer.yml
#	    ./bin/gsign --signer $SIGNER --release ${VERSION}-win-signed --destination ../gitian.sigs/ ../dogecoin/contrib/gitian-descriptors/gitian-win-signer.yml
#	    mv build/out/dogecoin-*win64-setup.exe ../dogecoin-binaries/${VERSION}
#	    mv build/out/dogecoin-*win32-setup.exe ../dogecoin-binaries/${VERSION}
#	fi
#	# Sign Mac OSX
#	if [[ $osx = true ]]
#	then
#	    echo ""
#	    echo "Signing ${VERSION} Mac OSX"
#	    echo ""
#	    ./bin/gbuild -i --commit signature=${COMMIT} ../dogecoin/contrib/gitian-descriptors/gitian-osx-signer.yml
#	    ./bin/gsign --signer $SIGNER --release ${VERSION}-osx-signed --destination ../gitian.sigs/ ../dogecoin/contrib/gitian-descriptors/gitian-osx-signer.yml
#	    mv build/out/dogecoin-osx-signed.dmg ../dogecoin-binaries/${VERSION}/dogecoin-${VERSION}-osx.dmg
#	fi
#	popd
#
#        if [[ $commitFiles = true ]]
#        then
#            # Commit Sigs
#            pushd gitian.sigs
#            echo ""
#            echo "Committing ${VERSION} Signed Sigs"
#            echo ""
#            git add ${VERSION}-win-signed/${SIGNER}
#            git add ${VERSION}-osx-signed/${SIGNER}
#            git commit -a -m "Add ${VERSION} signed binary sigs for ${SIGNER}"
#            popd
#        fi
#fi

# Sign binaries
if [[ $push == true ]]; then
  pushd gitian.sigs
  git push
  popd
fi

pushd dogecoin-binaries/${VERSION}
sha256sum *
popd