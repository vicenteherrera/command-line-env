#!/bin/bash

# Install a binary file from compressed GitHub repo releases channel
# by Vicente Herrera

set -e

# repository as username/reponame in GitHub URL
[ "$REPO" == "" ] && echo "REPO env variable required" && exit 1
# filename to download from releseas channel, include VERSION when it is part of the name
[ "$ZFILE" == "" ] && echo "ZFILE env variable required" && exit 1
# File or directory you want to move to /usr/local/bin if downloaded is a compressed file 
: "${FILE:=$ZFILE}"
# Name of the file or directory after moving to /usr/local/bin if different
: "${XFILE:=$FILE}"

http_code=$(curl --silent -L --max-time 30 --output version.txt --write-out "%{http_code}" "https://api.github.com/repos/${REPO}/releases/latest" ||:)
if [[ ${http_code} -eq 403 ]] ; then
  echo "Error 403: Forbidden"
  echo "GitHub API may have rate limited your IP address. Please wait and retry build."
  echo $url
  exit 1
elif [[ ${http_code} -lt 200 || ${http_code} -gt 299 ]] ; then
  echo "Error $http_code getting version"
  echo "Check URL is correct: $url"
  exit 1
fi
version=$(cat version.txt | jq ".tag_name" | xargs )
rm version.txt
usev=""
if [ "${version:0:1}" == "v" ]; then
  version=$(echo $version | cut -c2-)
  usev="v"
fi

echo "$XFILE $version (https://github.com/$REPO)" | tee sbom.txt

ZFILE=$(echo ${ZFILE/VERSION/$version})
FILE=$(echo ${FILE/VERSION/$version})
XFILE=$(echo ${XFILE/VERSION/$version})

url="https://github.com/${REPO}/releases/download/${usev}${version}/${ZFILE}"
echo "URL: $url"
echo "Download: $ZFILE, Extract: $FILE, Install as: $XFILE"

mkdir -p temp
cd temp

http_code=$(curl --silent -L --max-time 30 --output ${ZFILE} --write-out "%{http_code}" "$url" ||:)
if [[ ${http_code} -lt 200 || ${http_code} -gt 299 ]]; then
  echo "Error $http_code downloading file"
  echo "Check URL is correct and you are not API rate limited by your IP address"
  echo "URL: $url"
  exit 1
fi

echo "File downloaded"
[ ! -s "${ZFILE}" ] && echo "Error: file is empty, please wait and retry building to download again" && exit 1

extension="${ZFILE##*.}"
if [[ "${ZFILE}" != *"."* ]]; then
  echo "File is not compressed"
elif [ "$extension" == "deb" ]; then
  echo "File is a deb package"
  sudo apt-get install ./"${ZFILE}"
  rm "${ZFILE}"
elif [ "$extension" == "zip" ]; then
  echo "File is a zip"
  unzip "${ZFILE}" ${FILE} -d ./
  rm "${ZFILE}"
  sudo chmod a+x ${FILE}
  sudo chmod -R a+rX ${FILE}
  sudo mv ${FILE} /usr/local/bin/${XFILE}
elif [ "$extension" == "gz" ] || [ "$extension" == "tgz" ]; then
  echo "File is gzipped"
  tar -xvzf "${ZFILE}" ${FILE}
  rm "${ZFILE}"
  sudo chmod a+x ${FILE}
  sudo chmod -R a+rX ${FILE}
  sudo mv ${FILE} /usr/local/bin/${XFILE}
else
  echo "Unknown file type"
  exit 1
fi

cd ..
rm -rf ./temp

# if $FILE is a directory, you must change mode to the bin files in it manually
