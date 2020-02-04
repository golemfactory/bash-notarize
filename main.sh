#!/bin/bash
#title           :bash-notarize
#description     :This script will automate signing and notarizing process
#author		 	 :Muhammed Tanrikulu (mdt)
#date            :02022020
#version         :0.1    
#usage		 	 :./main.sh <ARGUMENTS>
#notes           :You will need Apple developer account, certificate and app-specific password
#bash_version    :3.2.57(1)-release
#==============================================================================

POSITIONAL=()
while [[ $# -gt 0 ]] 
do
	key="$1"
	case $key in
	    -a|--asc_provider)
	    ASC_PROVIDER="$2"
	    shift # past argument value
	    ;;
	    -u|--ac_username)
	    AC_USERNAME="$2"
	    shift
	    ;;
	    -p|--ac_password)
	    AC_PASSWORD="$2"
	    shift
	    ;;
	    -s|--app_sign)
	    export APP_SIGN="$2"
	    shift
	    ;;
	    -i|--bundle_id)
	    BUNDLE_ID="$2"
	    shift
	    ;;
	    -t|--bundle_target)
	    BUNDLE_TARGET="$2"
	    shift
	    ;;
	    -e|--entitlements)
	    export ENTITLEMENTS="$2"
	    shift
	    ;;
	    -d|--sleep_delay)
	    export SLEEP_DELAY=${2:-"60"}
	    shift
	    ;;
	    -h |--help)
		echo ""
	    echo "Help for Bash-Notarize Script"
	    echo
	    echo -e "-a | --asc_provider\t<Team ID>\t\t\t(If you don't know, run: xcrun altool --list-providers -u AC_USERNAME -p AC_PASSWORD)" 
	    echo -e "-u | --ac_username\t<Apple ID>"
	    echo -e "-p | --ac_password\t<App-specific password>\t\t(More: https://support.apple.com/en-us/HT204397)"
	    echo -e "-s | --app_sign\t\t<Certificate name>\t\t(More: https://developer.apple.com/support/certificates/)"
	    echo -e "-i | --bundle_id\t<Give a bundle id to identify project easily. e.g. network.golem.app>"
	    echo -e "-t | --bundle_target\t<Target file of the project>"
	    echo -e "-e | --entitlements\t<Additional permission list>\t(More: https://developer.apple.com/documentation/bundleresources/entitlements)"
	    echo -e "-d | --sleep_delay\t<Sleep delay for check iteration>"
	    echo
	    exit
	    ;;
	    *) # unknown option
	    POSITIONAL+=("$1") # save it in an array for later
	    shift # past argument
	    ;;
	esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

ZIP_NAME="binaries.zip" #Temporary zip name to upload binaries to notarization servers

basename "$BUNDLE_TARGET"
TARGET_NAME="$(basename -- $BUNDLE_TARGET)"

if [ -z "$ASC_PROVIDER" ] || [ -z "$AC_USERNAME" ] || [ -z "$AC_PASSWORD" ] || [ -z "$APP_SIGN" ] || [ -z "$BUNDLE_ID" ] || [ -z "$BUNDLE_TARGET" ] || [ ! -e "$BUNDLE_TARGET" ]; then
    echo "Argument error"
    exit
fi

# create temporary files
NOTARIZE_APP_LOG=$(mktemp notarize-app)
NOTARIZE_INFO_LOG=$(mktemp notarize-info)
TAR_BUCKET=$(mktemp -d tar-bucket.XXXX)
ZIP_BUCKET=$(mktemp -d zip-bucket.XXXX)

# delete temporary files on exit
function finish {
	rm "$NOTARIZE_APP_LOG" "$NOTARIZE_INFO_LOG"
	rm -rf "$TAR_BUCKET" "$ZIP_BUCKET"
}
trap finish EXIT

# ARGS: 
# FILE name of tar file 
function DoUntar() {

	local FILE="$1"

	if tar -xvf "$FILE" -C "$TAR_BUCKET"; then
		rm "$FILE"
		echo "Package Untarred"
	fi
}

# ARGS: 
# FILE name of tar file 
function DoTar() {

	local TAR_NAME="$1"
	cd "$ZIP_BUCKET"
	if tar -cvzf "../$TAR_NAME" *; then
		cd ".."
		echo "Package tar.gz is ready as ${TAR_NAME}"
		exit
	fi
}

# ARGS: 	
# FILE name of zip file 
function DoUnzip() {
	local FILE="$1"

	if unzip "$FILE" -d "$ZIP_BUCKET"; then
		rm "$FILE"
		echo "Package Unzipped"
	fi
}

# ARGS: 
# FILE name of zip file
function DoZip() {
	local ZIP_NAME="$1"
	cd "$TAR_BUCKET"
	if zip -r -X "../${ZIP_NAME}" *; then
		cd ".."
		echo "Package Zipped"
	fi
}

# ARGS: 
# INFO_NAME In case of several Code signing processes, information tag can be passed to idenitfy logs
# FILE file name 
function DoCodeSign {

    local INFO_NAME="$1"
    local FILE="$2"
    local IDENTITY=${APP_SIGN}
    local ENTITLEMENTS=${ENTITLEMENTS}
    local deep="" # TODO add optional deep support

    printf "\nINFO_NAME is ${INFO_NAME}\n"
    printf "FILE is ${FILE}\n"
    printf "IDENTITY is ${IDENTITY}\n"
    printf "ENTITLEMENTS is ${ENTITLEMENTS}\n\n"
    printf "Code signing ${INFO_NAME}...\n"

    codesign --verbose --timestamp --deep  --options=runtime --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$FILE" || echo "Could not code sign ${INFO_NAME}"
}

# ARGS: 
# FILE file name
function DoNotarize {

	local BUNDLE_ZIP="$1"
	echo "Notarizing..."
	# submit app for notarization
	if xcrun altool --notarize-app --primary-bundle-id "$BUNDLE_ID" --asc-provider "$ASC_PROVIDER" --username "$AC_USERNAME" --password "$AC_PASSWORD" --file "$BUNDLE_ZIP" > "$NOTARIZE_APP_LOG" 2>&1; then
		cat "$NOTARIZE_APP_LOG"
		RequestUUID=$(awk -F ' = ' '/RequestUUID/ {print $2}' "$NOTARIZE_APP_LOG")

		# check status periodically
		while sleep "$SLEEP_DELAY" && date; do
			# check notarization status
			if xcrun altool --notarization-info "$RequestUUID" --asc-provider "$ASC_PROVIDER" --username "$AC_USERNAME" --password "$AC_PASSWORD" > "$NOTARIZE_INFO_LOG" 2>&1; then
				cat "$NOTARIZE_INFO_LOG"

				# once notarization is complete, unpack, pack with tar.gz and exit
				if ! grep -q "Status: in progress" "$NOTARIZE_INFO_LOG"; then
					echo "Notarization done"
					break
				fi
			else
				cat "$NOTARIZE_INFO_LOG" 1>&2
				exit 1
			fi
		done
	else
		cat "$NOTARIZE_APP_LOG" 1>&2
		exit 1
	fi
}

export -f DoCodeSign

DoUntar "$BUNDLE_TARGET"
find "$TAR_BUCKET" -type f -perm +0111 -exec bash -c 'DoCodeSign "mac binaries" {}' \;
DoZip "$ZIP_NAME"
DoNotarize "./$ZIP_NAME"
DoUnzip "$ZIP_NAME"
DoTar "$TARGET_NAME"
