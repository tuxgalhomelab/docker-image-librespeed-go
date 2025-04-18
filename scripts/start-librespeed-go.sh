#!/usr/bin/env bash
set -E -e -o pipefail

librespeed_go_config="/data/librespeed-go/config/settings.toml"
librespeed_go_default_config="/data/librespeed-go/config/settings-default.toml"
librespeed_go_assets_dir="/data/librespeed-go/assets"
librespeed_go_default_assets_dir="/data/librespeed-go/assets-default"

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

setup_librespeed_go_config() {
    echo "Checking for existing LibreSpeed Go config ..."
    echo

    if [ -f ${librespeed_go_config:?} ]; then
        echo "Existing LibreSpeed Go configuration \"${librespeed_go_config:?}\" found"
    else
        echo "Using the default LibreSpeed Go configuration from ${librespeed_go_default_config:?}"
        cp ${librespeed_go_default_config:?} ${librespeed_go_config:?}
    fi
}

setup_librespeed_go_assets() {
    echo "Checking for existing LibreSpeed Go assets ..."
    echo

    if [ -f ${librespeed_go_assets_dir:?}/index.html ]; then
        echo "Existing LibreSpeed Go index.html asset \"${librespeed_go_assets_dir:?/index.html}\" found"
    else
        echo "Using the example single server full LibreSpeed Go index.html asset from ${librespeed_go_default_assets_dir:?}/example-singleServer-full.html"
        cp ${librespeed_go_default_assets_dir:?}/example-singleServer-full.html ${librespeed_go_assets_dir:?}/index.html
    fi
}

start_librespeed_go() {
    echo "Starting LibreSpeed Go ..."
    echo

    exec librespeed-go -c ${librespeed_go_config:?}
}

set_umask
setup_librespeed_go_config
setup_librespeed_go_assets
start_librespeed_go
