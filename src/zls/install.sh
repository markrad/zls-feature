#!/bin/bash
ZLS_VERSION=latest

set -e

if [ "$(id -u)" -ne 0 ]; then
	echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
	exit 1
fi

# Clean up (?)
# rm -rf /var/lib/apt/lists/*

ARCH="$(uname -m)"

# Checks if packages are installed and installs them if not
# Note this code assumes we are running on a distro with the apt package manager
check_packages() {
	if ! dpkg -s "$@" >/dev/null 2>&1; then
		if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
			echo "Running apt-get update..."
			apt-get update -y
		fi
		apt-get -y install --no-install-recommends "$@"
	fi
}

# make sure we have curl, xz-utils, and jq
check_packages ca-certificates curl xz-utils jq

# remove any old version
rm -f /usr/local/bin/zls
rm -rf /usr/local/lib/zls
mkdir /usr/local/lib/zls

INDEX_URL="https://zigtools-releases.nyc3.digitaloceanspaces.com/zls/index.json"

# determine the URL for the requested version
if [[ "$ZLS_VERSION" == "latest" ]]
then
    DOWNLOAD_VERSION=$(curl -sSL $INDEX_URL | jq -r '.latestTagged')
else
    HAVE_VERSION=$(curl -sSL $INDEX_URL | jq -r --arg VER "$ZLS_VERSION" '.versions | keys | map(select(. == $VER)) | length')
    if [[ "$HAVE_VERSION" != "1" ]]
    then
        echo -e "Requested version $ZLS_VERSION does not exist"
	    exit 1
    fi

    DOWNLOAD_VERSION=$ZLS_VERSION
fi

PACKAGE_URL="https://github.com/zigtools/zls/releases/download/$DOWNLOAD_VERSION/zls-$ARCH-linux.tar.xz"

curl -L $PACKAGE_URL | tar xJ -C /usr/local/lib/zls
ln -s /usr/local/lib/zls/zls /usr/local/bin/zls