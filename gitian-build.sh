#!/bin/bash

# Copyright (c) 2016 The Bitcoin Core developers
# Copyright (c) 2021 The Dogecoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

# GITIAN PROPERTIES
unset USE_LXC
unset USE_VBOX
export USE_DOCKER=1

#SYSTEMS TO BUILD
DESCRIPTORS=('linux' 'win' 'osx')

# What to do
sign=false
verify=false
build=false
commit=false
push=false
init=false

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
      DESCRIPTORS=()
      if [[ "$2" == *"l"* ]]; then
        DESCRIPTORS+=('linux')
      fi
      if [[ "$2" == *"w"* ]]; then
        DESCRIPTORS+=('win')
      fi
      if [[ "$2" == *"x"* ]]; then
        if [[ ! -e "gitian-builder/inputs/MacOSX10.11.sdk.tar.gz" && $build == true ]]; then
          echo "Cannot build for OSX, SDK does not exist. Will build for other OSes"
        else
          DESCRIPTORS+=('osx')
        fi
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

#######################
######## SETUP ########
#######################
if [[ $setup == true ]]; then
  git clone https://github.com/dogecoin/gitian.sigs.git
  git clone https://github.com/dogecoin/dogecoin-detached-sigs.git
  git clone $url

  git clone https://github.com/micaelmalta/gitian-builder
  pushd gitian-builder
  git fetch
  git checkout docker
  git reset --hard docker

   ./bin/make-base-vm --docker --arch amd64 --suite trusty
  ../setup/dependencies.sh
  popd
  exit

fi

#######################
######## BUILD ########
#######################
if [[ $build == true ]]; then

  # Set up build
  pushd ./dogecoin
  git remote set-url origin $url
  git fetch
  git checkout ${COMMIT}
  git reset --hard ${COMMIT}
  popd

  # Make output folder
  mkdir -p ./dogecoin-binaries/${VERSION}

  pushd ./gitian-builder

  make -j "${proc}" -C ../dogecoin/depends download SOURCES_PATH=$(pwd)/cache/common

  for descriptor in "${DESCRIPTORS[@]}"; do
    echo ""
    echo "Compiling ${VERSION} ${descriptor}"
    echo ""
    ./bin/gbuild -j ${proc} -m ${mem} --commit dogecoin=${COMMIT} --url dogecoin=${url} ../dogecoin/contrib/gitian-descriptors/gitian-${descriptor}.yml
  done

  popd
fi

######################
######## SIGN ########
######################
if [[ $sign == true ]]; then
  pushd gitian-builder

  for descriptor in "${DESCRIPTORS[@]}"; do
    echo ""
    echo "Signing ${VERSION} ${descriptor}"
    echo ""
    ./bin/gsign --signer $SIGNER --release ${VERSION}-${descriptor} --destination ../gitian.sigs/ ../dogecoin/contrib/gitian-descriptors/gitian-${descriptor}.yml
  done

  popd

  if [[ $commitFiles == true ]]; then
    # Commit to gitian.sigs repo
    echo ""
    echo "Committing ${VERSION} Unsigned Sigs"
    echo ""
    pushd gitian.sigs
    for descriptor in "${DESCRIPTORS[@]}"; do
      git add ${VERSION}-${descriptor}/${SIGNER}
    done
    git commit -a -m "Add ${VERSION} unsigned sigs for ${SIGNER}"
    popd
  fi
fi

######################
####### VERIFY #######
######################
if [[ $verify == true ]]; then
  pushd ./gitian-builder

  for descriptor in "${DESCRIPTORS[@]}"; do
    echo ""
    echo "Verifying v${VERSION} ${descriptor}"
    echo ""
    ./bin/gverify -v -d ../gitian.sigs/ -r ${VERSION}-${descriptor} ../dogecoin/contrib/gitian-descriptors/gitian-${descriptor}.yml
  done

  popd
fi

#####################
####### BUILD #######
#####################
if [[ $build == true ]]; then
  pushd gitian-builder
  mv build/out/dogecoin-*.tar.gz build/out/src/dogecoin-*.tar.gz ../dogecoin-binaries/${VERSION}
  mv build/out/dogecoin-*.zip build/out/dogecoin-*.exe ../dogecoin-binaries/${VERSION}
  mv build/out/dogecoin-*.dmg ../dogecoin-binaries/${VERSION}
  popd
fi

####################
####### PUSH #######
####################
if [[ $push == true ]]; then
  pushd gitian.sigs
  git push
  popd
fi

#######################
####### DISPLAY #######
#######################
pushd dogecoin-binaries/${VERSION}
echo ${VERSION}
sha256sum dogecoin-*
popd