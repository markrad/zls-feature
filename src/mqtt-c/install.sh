#!/bin/bash
MQTTC_VERSION=v1.1.6
set -e

if [ "$(id -u)" -ne 0 ]; then
	echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.' >&2
	exit 1
fi


# Clean up (?)
# rm -rf /var/lib/apt/lists/*

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

# make sure we have required packages
check_packages ca-certificates curl xz-utils jq cmake

INDEX_URL="https://api.github.com/repos/LiamBindle/MQTT-C/releases"

# determine the URL for the requested version
if [[ "$MQTTC_VERSION" == "latest" ]]
then
    DOWNLOAD_VERSION=$(curl -sSL $INDEX_URL | jq -r '.[0].tag_name')
else
    HAVE_VERSION=$(curl -sSL $INDEX_URL | jq -r --arg VER "$MQTTC_VERSION" '[ .[].tag_name ] | index($VER)')
    if [[ "$HAVE_VERSION" == "null" ]]
    then
        echo -e "Requested version $MQTTC_VERSION does not exist" >&2
	    exit 1
    fi

    DOWNLOAD_VERSION=$MQTTC_VERSION
fi

echo Dowlnoading version $DOWNLOAD_VERSION
PACKAGE_URL="https://github.com/LiamBindle/MQTT-C/archive/refs/tags/$DOWNLOAD_VERSION.tar.gz"

mkdir -p work
pushd work
mkdir -p mqttc
curl -L $PACKAGE_URL -o mqttc.tar.gz
tar xzf mqttc.tar.gz -C mqttc --strip-components 1
cd mqttc
mkdir build
cd build
echo Build and install
cmake -DMQTT_C_OpenSSL_SUPPORT=1 -DMQTT_C_EXAMPLES=0 ..
make
make install
popd
rm -rf work
