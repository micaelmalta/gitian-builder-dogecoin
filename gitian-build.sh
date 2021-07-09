#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
proc=2
mem=2000
scriptName=$(basename -- "$0")
url=https://github.com/dogecoin/dogecoin

function Help() {
echo "
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
--setup         Setup the gitian building environment. Uses KVM. If you want to use lxc, use the --lxc option. Only works on Debian-based systems (Ubuntu, Debian)
--detach-sign   Create the assert file for detached signing. Will not commit anything.
--no-commit     Do not commit anything to git
-h|--help	Print this help message
"
}

# Get options and arguments
while :; do
    echo $1
    case $1 in
        # Verify
        -v|--verify)
	          verify=true
            ;;
        # Build
        -b|--build)
	          build=true
            ;;
        # Sign binaries
        -s|--sign)
	          sign=true
            ;;
        # Build then Sign
        -B|--buildsign)
            sign=true
            build=true
            ;;
        # PGP Signer
        -S|--signer)
            if [ -n "$2" ]
            then
              SIGNER=$2
              shift
            else
              echo 'Error: "--signer" requires a non-empty argument.'
              exit 1
            fi
            ;;
        # Operating Systems
        -o|--os)
            if [ -n "$2" ]
            then
              linux=false
              windows=false
              osx=false
              if [[ "$2" = *"l"* ]]
              then
                  linux=true
              fi
              if [[ "$2" = *"w"* ]]
              then
                  windows=true
              fi
              if [[ "$2" = *"x"* ]]
              then
                  osx=true
              fi
		          shift
	          else
              echo 'Error: "--os" requires an argument containing an l (for linux), w (for windows), or x (for Mac OSX)\n'
              exit 1
	          fi
	          ;;
        # Help message
        -h|--help)
            Help
            exit 0
            ;;
        # Number of Processes
        -j|--jobs)
            if [ -n "$2" ]
            then
              proc=$2
              shift
            else
              echo 'Error: "-j" requires an argument'
              exit 1
            fi
            ;;
        # Memory to allocate
        -m|--mem)
            if [ -n "$2" ]
            then
              mem=$2
              shift
            else
              echo 'Error: "-m" requires an argument'
              exit 1
            fi
            ;;
        # URL
        -u|--url)
            if [ -n "$2" ]
            then
              url=$2
              shift
            else
              echo 'Error: "-u" requires an argument'
              exit 1
            fi
            ;;
              # Commit files
              --no-commit)
                  commitFiles=false
                  ;;
              # Setup
              --setup)
                  setup=true
                  ;;
	*)               # Default case: If no more options then break out of the loop.
             break
    esac
    shift
done

# GITIAN PROPERTIES
unset USE_LXC
unset USE_VBOX
export USE_DOCKER=1
# Set up LXC
if [[ $setup = true ]]
then
  echo "Setup Docker..."
  ./gitian_setup_docker.sh
  git clone https://github.com/micaelmalta/gitian-builder
  git clone $url

  pushd dogecoin
  git fetch
  git checkout ${COMMIT}
  popd

  pushd gitian-builder
  #git checkout remove_trusty_esm
  ./bin/make-base-vm --docker --arch amd64 --suite trusty

  ../gitian_depedencies.sh

  mkdir -p ../builds/${COMMIT}
  popd
  exit
fi

if [[ $build = true ]]
then
  make -C ../dogecoin/depends download SOURCES_PATH=`pwd`/cache/common
fi

pushd gitian-builder
# Get signer
if [[ -n "$1" ]]
then
    SIGNER=$1
    shift
fi

# Get version
if [[ -n "$1" ]]
then
    VERSION=$1
    shift
fi

if [[ -z $SIGNER ]]
then
  echo "Signer not specified"
  Help
  exit 1
fi

if [[ -z $VERSION ]]
then
  echo "Version not specified"
  Help
  exit 1
fi

function build() {
  if [[ $build = true ]]
  then
    ./bin/gbuild -m ${mem} -j ${proc} --commit dogecoin=${VERSION} --url dogecoin=${url} ../dogecoin/contrib/gitian-descriptors/gitian-$1.yml
  fi
}

function verify() {
  if [[ $verify = true ]]
  then
    ./bin/gverify -v -d ../gitian.sigs/ -r ${VERSION}-$1 ../dogecoin/contrib/gitian-descriptors/gitian-$1.yml
  fi
}

function sign() {
  if [[ $sign = true ]]
  then
    ./bin/gsign --signer "$SIGNER" --release ${VERSION}-$1 --destination ../gitian.sigs/ ../dogecoin/contrib/gitian-descriptors/gitian-$1.yml
  fi
}

function move() {
  mv build/out/dogecoin-*.tar.gz build/out/src/dogecoin-*.tar.gz ../builds/${VERSION}/
}

function commit() {
  if [[ $commitFiles = true ]]
  then
    pushd gitian.sigs
    git add ${VERSION}-linux/${SIGNER}
    popd
  fi
}
echo "FOLDER"
pwd

if [[ $linux = true ]]
then
  build "linux"
  verify "linux"
  sign "linux"
  move
  commit "linux"
fi

if [[ $windows = true ]]
then
  build "win"
  verify "win"
  sign "win"
  move
  commit "win"
fi

if [[ $osx = true ]]
then
  build "osx"
  verify "osx"
  sign "osx"
  move
  commit "osx"
fi

if [[ $commitFiles = true ]]
then
    # Commit to gitian.sigs repo
    echo ""
    echo "Committing ${VERSION} Unsigned Sigs"
    echo ""
    pushd gitian.sigs
    git commit -a -m "Add ${commit} unsigned sigs for ${signer}"
    popd
fi
popd

pushd builds/${COMMIT}
sha256sum *
popd