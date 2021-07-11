# Gitian building

Setup instructions for a Gitian build of Dogecoin Core using a Docker.

Gitian is the deterministic build process that is used to build the Dogecoin Core executables. It provides a way to be reasonably sure that the executables are really built from the source on GitHub. It also makes sure that the same, tested dependencies are used and statically built into the executable.

Multiple developers build the source code by following a specific descriptor ("recipe"), cryptographically sign the result, and upload the resulting signature. These results are compared and only if they match, the build is accepted and uploaded to dogecoin.com.

More independent Gitian builders are needed, which is why this guide exists. It is preferred you follow these steps yourself instead of using someone else's VM image to avoid 'contaminating' the build.


# SUPPORTED DISTRIBUTION

    ubuntu
    debian
    centos
    fedora
    archlinux
    macos

# PREREQUISITE
## AUTOMATED INSTALL
    1. Launch automated script (ONLY ONCE)

        ./gitian-build.sh --init

## MANUAL INSTALL
    1. Install Docker

        https://docs.docker.com/engine/install/

    2. Generate GPG key

        https://docs.github.com/en/github/authenticating-to-github/managing-commit-signature-verification/generating-a-new-gpg-key

    3. INSTALL those packages:

        sudo git make wget brew(MACOS ONLY)

    
## SETUP  (ONLY ONCE)
    ./gitian-build.sh --setup

## BUILD
    ./gitian-build.sh -j <jobs> -m <mem> --build <signer_name:required> <version:required>

## VERIFY
    ./gitian-build.sh --verify <signer_name:required> <version:required>

## VERSION vs COMMIT
  For release version: omit `v` 

    ./gitian-build.sh -j <jobs> -m <mem> --build <signer_name:required> 1.14.3

  For commit or branch: use `--commit`
    
    ./gitian-build.sh -j <jobs> -m <mem> --commit --build <signer_name:required> <branch|hash>

## PUSH SIGN
    ./gitian-build.sh --push

## CUSTOM REPOSITORY
    ./gitian-build.sh -j <jobs> -m <mem> --build --url <repo_url> <signer_name:required> <version:required>

## COMPLETE LIST OF PARAMETERS
    ./gitian-build.sh --help

## Examples:
    ./gitian-build.sh --setup
    
    ./gitian-build.sh -j 8 -m 8192 --url https://github.com/micaelmalta/dogecoin -B mmicael 1.14.3

    ./gitian-build.sh -j 8 -m 8192 -B mmicael 1.14.3

    or

    ./gitian-build.sh -j 8 -m 8192 --commit -B mmicael 1.14.4-dev

    ./gitian-build.sh --push

## License

Dogecoin Core is released under the terms of the MIT license. See COPYING for more information or see https://opensource.org/licenses/MIT.