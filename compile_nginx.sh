#!/usr/bin/env bash
set -e

if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
    echo "FATAL: Expected ARGS:"
    echo "1. os-version: 18.04"
    echo "2. nginx-version: ie. 1.18.0"
    echo "3. passenger-version: 6.0.8"
    echo ""
    echo "Usage Examples:"
    echo "./compile_nginx.sh 18.04 1.18.0 6.0.8"
    exit 22
fi

case $1 in
    18.04)
	OPERATING_SYSTEM_CODENAME=bionic
	;;
    *)
	echo "Unknown operating system"
	exit 1
	;;
esac

# create output build logs folder
mkdir -p output/build_logs
# define build log file
build_log_file="output/build_logs/build-ubuntu-$1-nginx-$2-passenger-$3.log"
# define the next tag
tag="cloud66-nginx:ubuntu-$1-nginx-$2-passenger-$3"
# remove previous build
docker rmi --force $tag >/dev/null 2>&1
# build new version
docker build --rm --build-arg OPERATING_SYSTEM_VERSION=$1 --build-arg OPERATING_SYSTEM_CODENAME=$OPERATING_SYSTEM_CODENAME --build-arg NGINX_VERSION=$2 --build-arg PASSENGER_VERSION=$3 --tag $tag . >$build_log_file 2>&1
