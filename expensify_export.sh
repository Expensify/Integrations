#!/bin/bash

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

###### Utility Functions ######

# build json object for POST
function build_json_request() {
    REQ="requestJobDescription="
    REQ+="{'credentials':{'partnerUserID':'$partnerUserID',"
    REQ+="'partnerUserSecret':'$partnerUserSecret'},"
    REQ+="'test':'true',"
    REQ+="'type':'file',"
    REQ+="'fileExtension':'csv',"
    REQ+="'onReceive':{'immediateResponse':['returnRandomFileName']},"
    REQ+="'inputSettings':{'type':'combinedReportData','limit':'2','reportState':'SUBMITTED'},"
    REQ+="'inputData':{'customHeader':'',},"
    REQ+="'onFinish':{'foreachReport':[{'markAsExported':'csv'}],}"
    REQ+="}"
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

# Parse wget output
function parse_curl_output() {
    #stripping the newlines out of the curl output
    #to prevent unpredictable behavior
    CURLEXIT="$1"
    shift

    local CURLOUT="${@//[$'\r']/\r}"
    CURLOUT="${CURLOUT//[$'\n']/\n}"
    log "debug" "parse_curl_output(): $CURLOUT"

    if ( echo "$CURLOUT" | grep -q "400 - Bad Request" ); then
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
        esac
        shift
    done
}

# Process command-line args
function process_args() {
    while [ -n "$1" ]; do
        case $1 in
            "--help" | "-?")
                #already handled in preprocess_args
                ;;
            "-v")
                #already handled in preprocess_args
                ;;
            "-c")
                test_paired_args "$1" "$2"
                CREDS_FILE=$2
                shift
                ;;
            "-f")
                test_paired_args "$1" "$2"
                EXPORT_FILE=$2
                shift
                ;;
            *)
                log "error" "unrecognized parameter $1"
                usage
        esac
        shift
    done
}

# Set script defaults, override with command-line args
function set_defaults() {
    CREDS_FILE="./creds.sh"
    EXPORT_FILE="./expensify_export.$(date +'%Y%m%d').csv"
    TEMPLATE_FILE="./template.txt"
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
    CMDLIST="$@"
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
    PARAMS+=("[-v]")
    PARAMS+=("[-f export_filename]")
    PARAMS+=("[-c credentials_file]")

    echo "usage: $0 ${PARAMS[@]}"
    exit 255
}

###### MAIN ######
preprocess_args "$@"
test_required_cmds curl echo grep
set_defaults
process_args "$@"

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

## Test export filepath ##
EXPORT_DIR=$(dirname $EXPORT_FILE)
log "debug" "export path: $EXPORT_DIR"
log "debug" "export filename: $EXPORT_FILE"
if [ ! -d $EXPORT_DIR ] || [ ! -w $EXPORT_DIR ]; then
    log "error" "export filepath $EXPORT_DIR is not a writeable directory"
    exit 1
fi

## Build curl export request url ##
HOSTNAME="pdftest.expensify.com"
URL="https://$HOSTNAME/Integration-Server/servlet/ExpensifyIntegrations"
log "info" "sending curl request to $URL"

## Build curl export request json ##
JSON=$(build_json_request)
log "debug" "json_request: $JSON"

## execute curl export request ##
CURL_OPTS="--include -sL -H 'Expect:' --data \""$JSON"\" --data \"template=@$TEMPLATE_FILE\" $URL"
#CURL_OPTS="-sL -H 'Expect:' --data \""$JSON"\" --data \"template=foobar\" $URL"
CURL_CMD="curl $CURL_OPTS"
log "debug" "curl command: $CURL_CMD"
CURL_OUTPUT=$(eval "$CURL_CMD")
CURL_EXIT="$?"
parse_curl_output "$CURL_EXIT" "$CURL_OUTPUT"
exit 1

ATTEMPT_COUNT=0
DOWNLOAD_STATUS="false"
while [[ "$DOWNLOAD_STATUS" != "true" ]]; do
    log "debug" "download attempt $ATTEMPT_COUNT"
    URL="integrations.expensify.com/index.php"
    CURL_OUTPUT=$(curl -o $EXPORT_FILE $URL 2>&1)
    CURL_EXIT="$?"
    if [ $CURL_EXIT -ne 0 ]; then
        DOWNLOAD_STATUS="true"
    else
        parse_curl_output "$CURL_EXIT" "$WGET_OUTPUT"
    fi

    let ATTEMPT_COUNT=$ATTEMPT_COUNT+1
    if [ $ATTEMPT_COUNT -ge 5 ]; then
        log "error" "download status still unsuccessful after 5 minutes"
        exit 1
    fi

    sleep 5
done

if [ "$DOWNLOAD_STATUS" == "true" ]; then
    log "info" "download status successful"
    exit 0
fi

