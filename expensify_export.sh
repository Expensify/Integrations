#!/bin/bash
EXPENSIFY_EXPORT_VERSION=1.3
###############################################################
### expensify_export.sh - issues a request for an Expensify
### export file, and downloads the file
###############################################################

###############################################################
### This program is free software released under the MIT
### License: http://en.wikipedia.org/wiki/Mit_license
### Copyright (c) 2013, Expensify, Inc.
### All rights reserved.
###############################################################

###############################################################
### Utility Functions
###############################################################

# build json object for POST
function build_json_request() {
    local REQ_FUNCTION="$1"
    if [ "$REQ_FUNCTION" == "requestExport" ]; then
        local REQ="requestJobDescription="
        REQ+="{'credentials':{'partnerUserID':'$partnerUserID',"
        REQ+="'partnerUserSecret':'$partnerUserSecret'},"
        if [ "$TEST_FLAG" == "true" ]; then
            REQ+="'test':'true',"
        fi
        REQ+="'type':'file',"
        REQ+="'outputSettings':{'fileExtension':'csv'},"
        REQ+="'onReceive':{'immediateResponse':['returnRandomFileName']},"
        REQ+="'inputSettings':{'type':'combinedReportData','reportState':'REIMBURSED','filters':{'markedAsExported':'Oracle','startDate':'2013-01-01'}},"
        REQ+="'onFinish':[{'actionName':'markAsExported','label':'Oracle'}]"
        REQ+="}"
    elif [ "$REQ_FUNCTION" == "getFile" ]; then
        local TARGET="$2"
        local REQ="requestJobDescription="
        REQ+="{'credentials':{'partnerUserID':'$partnerUserID',"
        REQ+="'partnerUserSecret':'$partnerUserSecret'},"
        REQ+="'fileName':'$TARGET' }"
    fi
    echo "$REQ"
}

# Output control
function log() {
    if [[ ! ( -z "$VERBOSE" && "$1" == "debug" ) ]]; then
        echo -n "$1:"
        shift
        while [ -n "$1" ]; do
            echo -n " $1"
            shift
        done
        echo ""
    fi
}

# Parse curl output for known errors
function parse_curl_status() {
    #stripping the newlines out of the curl output
    #to prevent unpredictable behavior
    local CURLOUT="${@//[$'\r']/\r}"
    CURLOUT="${CURLOUT//[$'\n']/\n}"
    log "debug" "parse_curl_status(): $CURLOUT"

    if ( echo "$CURLOUT" | grep -q "200 OK" ); then
        log "info" "curl returned 200 success"
        return
    elif ( echo "$CURLOUT" | grep -q "400 - Bad Request" ); then
        log "error" "curl returned 400, badly formed request"
        exit 1
    elif ( echo "$CURLOUT" | grep -q "401 Unauthorized" ); then
        log "error" "curl returned 401, authentication failure"
        exit 1
    elif ( echo "$CURLOUT" | grep -q "403 Forbidden\|403 - Invalid Credentials" ); then
        log "error" "curl returned 403, invalid credentials"
        exit 1
    elif ( echo "$CURLOUT" | grep -q "404 Not Found" ); then
        log "error" "curl returned 404, page not found"
        exit 1
    elif ( echo "$CURLOUT" | grep -q "HTTP Status 500 - requestJobDescription" ); then
        log "error" "curl returned 500, problem with JSON - missing requestJobDescription"
        exit 1
    elif ( echo "$CURLOUT" | grep -q "HTTP Status 500 - JSONObject" ); then
        log "error" "curl returned 500, problem with JSON request"
        exit 1
    elif ( echo "$CURLOUT" | grep -q "500 Internal Server Error" ); then
        log "error" "curl returned 500, internal server error"
        exit 1
    else
        log "warn" "curl request passed with unknown status: $CURLOUT"
        return 1
    fi
}

# Process command-line args
function preprocess_args() {
    while [ -n "$1" ]; do
        case $1 in
            "--help" | "-?")
                usage
                ;;
            "-v")
                VERBOSE=true
                ;;
            "--version")
                version
                ;;
        esac
        shift
    done
}

# Process command-line args
function process_args() {
    while [ -n "$1" ]; do
        case $1 in
            # Triggers the usage/help output function
            "--help" | "-?")
                #already handled in preprocess_args
                ;;
            # Sets the global verbose property 
            "-v")
                #already handled in preprocess_args
                ;;
            # Specify the credentials file
            "-c")
                test_paired_args "$1" "$2"
                CREDS_FILE=$2
                shift
                ;;
            # Specify the export filename
            "-f")
                test_paired_args "$1" "$2"
                EXPORT_FILE=$2
                shift
                ;;
            # Specify the file path for export files
            "-F")
                test_paired_args "$1" "$2"
                EXPORT_FILEPATH=$2
                shift
                ;;
            # Specify the template file location
            "-t")
                test_paired_args "$1" "$2"
                TEMPLATE_FILE=$2
                shift
                ;;
            # Adds "test" parameter to JSON
            "-T")
                TEST_FLAG="true"
                shift
                ;;
            # Force support for an older version of curl
            "-p")
                CURL_SUPPORTS_DATA_URLENCODE=false
                shift
                ;;
            *)
                log "error" "unrecognized parameter $1"
                usage
        esac
        shift
    done
}

function rawurlencode() {
  local string="$1"
  local strlen=${#string}
  local encoded=""

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "$encoded"
}

version_cmp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Set script defaults, override with command-line args
function set_defaults() {
    # file containing the authentication credentials
    CREDS_FILE="./creds.sh"

    # file containing the file export template
    TEMPLATE_FILE="./template.txt"

    # filename where the downloaded file should be saved
    EXPORT_FILEPATH="./"

    # filename where the downloaded file should be saved
    EXPORT_FILE="expensify_export.$(date +'%Y%m%d').csv"

    # hostname for the expensify integrations server
    HOSTNAME="https://integrations.expensify.com"

    # If your version of curl is < 7.18.0, you can't use
    # --data-urlencode, so provide a mechanism to turn that off
    # For versions that don't have --data-urlencode we encode it in bash which
    # is a bit hacky.  Avoid if you can.
    CURL_SUPPORTS_DATA_URLENCODE=true
    CURL_MIN_REQUIRED_VERSION="7.18.0"

    # maximum attempts to download the export file
    MAX_DOWNLOAD_ATTEMPTS=30
}

# For command-line args that have a parameter
function test_paired_args() {
    log "debug" "caught option \"$1\", testing argument"
    if [ -z "$2" ] || [[ "$2" == \-* ]]; then
        log "error" "option $1 must have an argument"
        usage
    fi
}

# Test for commands that the script requires
function test_required_cmds() {
    local CMDLIST="$@"
    log "debug" "testing availability of necessary commands"
    for cmd in $CMDLIST; do
        CMD=$(which $cmd)
        if [ -z "$CMD" ] || [ ! -x "$CMD" ]; then
            log "error" "required command $cmd not found or not executable"
            exit 1
        fi
    done
    log "debug" "finished checking for necessary commands"
}

# Display Usage
function usage() {
    PARAMS=()
    PARAMS+=("[-Tvp]")
    PARAMS+=("[-f export_filename]")
    PARAMS+=("[-F export_file_path]")
    PARAMS+=("[-c credentials_file]")
    PARAMS+=("[-t template_file]")
    PARAMS+=("[--version]")

    echo "Usage: $0 ${PARAMS[@]}"
    echo "Options:"
    echo "  -T          Test the export: do not flag reports as exported, allowing for repeated export"
    echo "  -v          Verbose output: useful for debugging and testing"
    echo "  -p          Curlless URL encode: URL encode template using bash instead of curl (for curl version < 7.18.0)"
    echo "  --version   Show the version number and exit"
    exit 255
}

function version() {
    echo "$0 version $EXPENSIFY_EXPORT_VERSION"
    exit 255
}

###############################################################
### MAIN
###############################################################
preprocess_args "$@"
test_required_cmds curl echo grep cut
set_defaults
process_args "$@"

# If we think we can use curl data-urlencode, double check and override if not
CURL_VERSION=$(curl --version | grep -oE '^curl ([0-9.]+)' | cut -f2 --delimiter=" ")

version_cmp "$CURL_MIN_REQUIRED_VERSION" "$CURL_VERSION"
CURL_SUPPORTS_URLENCODE=$?

log "debug" "Version compare for curl returned $CURL_SUPPORTS_URLENCODE for $CURL_VERSION"

if [ $CURL_SUPPORTS_DATA_URLENCODE ]; then
    if [ $CURL_SUPPORTS_URLENCODE -eq 1 ]; then
        log "info" "Installed version of curl doesn't support data-urlencode. (Use -p to avoid this message)"
        CURL_SUPPORTS_DATA_URLENCODE=false
    fi
fi

## Test and import creds file ##
if [ ! -r $CREDS_FILE ]; then
    log "error" "credentials file $CREDS_FILE not found"
    exit 1
elif [[ ! `stat -c %a $CREDS_FILE` == ?00 ]]; then
    log "info" "credentials file $CREDS_FILE has loose permissions"
fi
. $CREDS_FILE

if [ -z $partnerUserID -o -z $partnerUserSecret ]; then
    log "error" "partner credentials not set"
    exit 1
fi

## Test template file ##
if [ ! -r $TEMPLATE_FILE ]; then
    log "error" "template file $TEMPLATE_FILE not found"
    exit 1
fi

## Test export filepath ##
log "debug" "export file path: $EXPORT_FILEPATH"
if [ ! -d $EXPORT_DIR ] || [ ! -w $EXPORT_DIR ]; then
    log "error" "export filepath $EXPORT_FILEPATH is not a writeable directory"
    exit 1
fi
EXPORT_FILE="$EXPORT_FILEPATH""$EXPORT_FILE"
log "debug" "export filename: $EXPORT_FILE"

## Update the template_data to be urlencoded if needed
TEMPLATE_DATA=$(cat "$TEMPLATE_FILE")
if $CURL_SUPPORTS_DATA_URLENCODE ; then
    CURL_DATA_FLAG="--data-urlencode"
else
    CURL_DATA_FLAG="--data"
    TEMPLATE_DATA=$(rawurlencode "$TEMPLATE_DATA")
fi

## Build curl export request ##
URL="$HOSTNAME/Integration-Server/ExpensifyIntegrations"
JSON=$(build_json_request "requestExport")
log "debug" "json_request: $JSON"
CURL_OPTS="--include -sL -H 'Expect:' $CURL_DATA_FLAG \""$JSON"\" $CURL_DATA_FLAG 'template=$TEMPLATE_DATA' $URL"
CURL_CMD="curl $CURL_OPTS"
log "debug" "curl command: $CURL_CMD"
log "info" "sending curl request to $URL"

## execute curl export request ##
CURL_OUTPUT=$(eval "$CURL_CMD")
parse_curl_status "$CURL_OUTPUT"

## capture exported filename ##
EXPORTED_TARGET=$(echo "$CURL_OUTPUT" | grep -o "export[a-zA-Z0-9\-]*\.csv")
if [ $? -ne 0 ]; then
    log "error" "curl result didn't have a recognizable filename"
    exit 1
fi
log "info" "exported target filename: $EXPORTED_TARGET"

## build curl getFile request ##
URL="$HOSTNAME/Integration-Server/ExpensifyIntegrations"
JSON=$(build_json_request "getFile" "$EXPORTED_TARGET")
log "debug" "json_request: $JSON"
CURL_OPTS="-sL -D /dev/stdout -H 'Expect:' $CURL_DATA_FLAG \""$JSON"\" -o $EXPORT_FILE $URL"
CURL_CMD="curl $CURL_OPTS"
log "debug" "curl command: $CURL_CMD"
log "info" "sending curl request to $URL"

## loop curl getFile requests ##
ATTEMPT_COUNT=0
DOWNLOAD_STATUS="false"
while [[ "$DOWNLOAD_STATUS" != "true" ]]; do
    log "debug" "download attempt $ATTEMPT_COUNT"
    CURL_OUTPUT=$(eval "$CURL_CMD")
    parse_curl_status "$CURL_OUTPUT"

    CURL_EXIT=$?
    if [ "$CURL_EXIT" -eq 0 ]; then
        DOWNLOAD_STATUS="true"
        break
    fi

    let ATTEMPT_COUNT=$ATTEMPT_COUNT+1
    if [ $ATTEMPT_COUNT -ge $MAX_DOWNLOAD_ATTEMPTS ]; then
        log "error" "download status still unsuccessful after $MAX_DOWNLOAD_ATTEMPTS tries"
        exit 1
    fi

    sleep 5
    log "info" "retrying curl request to $URL"
done

if [ "$DOWNLOAD_STATUS" == "true" ]; then
    log "info" "download status successful"
    exit 0
fi

