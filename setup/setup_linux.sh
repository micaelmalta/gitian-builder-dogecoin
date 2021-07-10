#!/bin/bash

$package_manager_update

if ! command -v sudo &> /dev/null
then
  $package_manager_install sudo
fi
exit 1

if command -v sudo &> /dev/null
then
  export sudo="sudo "
fi