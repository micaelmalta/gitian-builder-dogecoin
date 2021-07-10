#!/bin/bash
# Copyright (c) 2021 The Dogecoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

oss_patch_url="https://bitcoincore.org/cfields/osslsigncode-Backports-to-1.7.1.patch"
oss_patch_hash="a8c4e9cafba922f89de0df1f2152e7be286aba73f78505169bc351a7938dd911"

oss_tar_url="https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/osslsigncode/1.7.1-1/osslsigncode_1.7.1.orig.tar.gz"
oss_tar_hash="f9a8cdb38b9c309326764ebc937cba1523a3a751a7ab05df3ecc99d18ae466c9"

macos_sdk_url="https://bitcoincore.org/depends-sources/sdks/MacOSX10.11.sdk.tar.gz"
macos_sdk_hash="bec9d089ebf2e2dd59b1a811a38ec78ebd5da18cbbcd6ab39d1e59f64ac5033f"


mkdir -p inputs

pushd inputs

[[ -f $(basename -- $oss_patch_url) ]] || wget $oss_patch_url -O $(basename -- $oss_patch_url)
echo "${oss_patch_hash} $(basename -- $oss_patch_url)" | sha256sum -c || { echo "Signature for $(basename -- $oss_patch_url) don't match"; exit 1; }

[[ -f $(basename -- $oss_tar_url) ]] || wget $oss_tar_url -O $(basename -- $oss_tar_url)
echo "${oss_tar_hash} $(basename -- $oss_tar_url)" | sha256sum -c || { echo "Signature for $(basename -- $oss_tar_url) don't match"; exit 1; }

[[ -f $(basename -- $macos_sdk_url) ]] || wget $macos_sdk_url -O $(basename -- $macos_sdk_url)
echo "${macos_sdk_hash} $(basename -- $macos_sdk_url)" | sha256sum -c || { echo "Signature for $(basename -- $macos_sdk_url) don't match"; exit 1; }

popd