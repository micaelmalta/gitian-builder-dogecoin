# gitian-builder-dogecoin

# PREREQUISITE
    1. Install Docker
        https://docs.docker.com/engine/install/

    2. Generate GPG key
        ex: gpg --full-generate-key

    3. INSTALL git

    4. INSTALL make

    5. INSTALL wget

## SETUP  (ONLY ONCE)
    ./gitian-build.sh --setup

## BUILD
    ./gitian-build.sh -j <jobs> -m <mem> --build <signer_name> <version>

## SIGN
    ./gitian-build.sh --sign <signer_name> <version>

## BUILD AND SIGN
    ./gitian-build.sh -j <jobs> -m <mem> -B <signer_name> <version>

## VERIFY
    ./gitian-build.sh --verify <signer_name> <version>

## VERSION vs COMMIT
  For release version: omit `v` 

    ./gitian-build.sh -j <jobs> -m <mem> --build <signer_name> 1.14.3

  For commit or branch: use `--commit`
    
    ./gitian-build.sh -j <jobs> -m <mem> --commit --build <signer_name> <branch|hash>

## PUSH SIGN
    ./gitian-build.sh --push
    
## Examples:
    ./gitian-build.sh --setup

    ./gitian-build.sh -j 8 -m 8192 -B mmicael 1.14.3

    or

    ./gitian-build.sh -j 8 -m 8192 --commit -B mmicael 1.14.4-dev

    ./gitian-build.sh --push
    