#!/bin/bash
####################################################################################################
# IP Information & Geolocation Lookup
# Written by @Jynx
# https://github.com/jynxified
# jynxified@proton.me
# 
# History:
# 1.0.0 (2026-08-19) - Initial version.
#
# Disclaimer:
# This script is provided "as is" without any warranty of any kind, either expressed or implied.
# Use it entirely at your own risk. The author (that's me) shall not be liable for any damages,
# data loss, system failures, or serious trouble you, your relatives, their neighbours or beloved
# pets might get into caused by the use or misuse of this script.
#
# Licensed under "CC BY-NC-ND 4.0" (https://creativecommons.org/licenses/by-nc-nd/4.0/).
####################################################################################################

# Text colors
BOLD="\e[1m"
BLUE="\e[34m"
MAGENTA="\e[35m"
YELLOW="\e[33m"
RED="\e[31m"
GREEN="\e[32m"
NC="\e[0m"

# ipinfo details
LOOKUP_URL="ipinfo.io"
LOOKUP_CURL_COMMAND="curl --max-time 10 -L --max-redirs 5"
LOOKUP_API_KEY_HEADER="Authorization: Bearer"
LOOKUP_OWN_KEYWORD="what-is-my-ip"

IPINFO_API_KEY=""

# Variables
P_API_KEY_FILE=""
P_THROTTLE_DELAY=0
P_IP_LIST=()
P_SHOW_IP="N"
P_SHOW_IP_REGION="N"
P_SHOW_IP_CITY="N"
P_SHOW_IP_NATION="N"
P_SHOW_IP_ZIPCODE="N"
P_SHOW_IP_GEOLOCATION="N"
P_VERBOSE_MODE="N"
P_ULTRA_VERBOSE_MODE="N"

####################################################################################################
# Validate and extract input parameters
####################################################################################################

#
# Displays usage information for the script with all parameters and options.
#
function showHelp {

    echo
    echo -e "----------------------------------------------------------------------------------"
    echo -e "                     ${BOLD}IP Information & Geolocation Lookup${NC}"
    echo -e "----------------------------------------------------------------------------------"
    echo -e "    Version 1.0.0 | ${YELLOW}@${BLUE}Jynx${NC} | jynxified@proton.me | ${BLUE}https://github.com/jynxified${NC}"
    echo -e "----------------------------------------------------------------------------------"
    echo
    echo -e "Usage: ip-lookup ${MAGENTA}OPTIONS${NC} [${YELLOW}IP${NC} ...]"
    echo
    echo -e "  ${MAGENTA}-a, --apikey FILE${NC}\t\t${BOLD}OPTIONAL${NC}. File containing an ipinfo API access key, if you"
    echo -e "\t\t\t\thave an account and want to use its extended lookup limits."
    echo -e "\t\t\t\tOtherwise, unauthenticated requests are made without a token,"
    echo -e "\t\t\t\tsubject to the corresponding lookup limits. You can find more"
    echo -e "\t\t\t\tinformation on this issue here:"
    echo -e "\t\t\t\t${BLUE}https://ipinfo.io/blog/how-to-get-ip-geolocation-api-key${NC}"
    echo    
    echo -e "  ${MAGENTA}-t, --throttle SECONDS${NC}\t${BOLD}OPTIONAL${NC}. Delay in seconds between two consecutive lookups."
    echo -e "\t\t\t\tDepending on your account type, ipinfo only allows a certain"
    echo -e "\t\t\t\tnumber of requests (1,000 per day for free accounts). This"
    echo -e "\t\t\t\toption can be used to throttle query requests accordingly."
    echo -e "\t\t\t\tThe default value is $P_THROTTLE_DELAY."
    echo    
    echo -e "  ${MAGENTA}-i, --ip${NC}\t\t\t${BOLD}OPTIONAL${NC}. Display the IP address itself."
    echo    
    echo -e "  ${MAGENTA}-r, --region${NC}\t\t\t${BOLD}OPTIONAL${NC}. Display the region of the IP address."
    echo    
    echo -e "  ${MAGENTA}-c, --city${NC}\t\t\t${BOLD}OPTIONAL${NC}. Display the city of the IP address."
    echo    
    echo -e "  ${MAGENTA}-n, --nation${NC}\t\t\t${BOLD}OPTIONAL${NC}. Display the nation of the IP address."
    echo    
    echo -e "  ${MAGENTA}-z, --zipcode${NC}\t\t\t${BOLD}OPTIONAL${NC}. Display the zip code of the IP address."
    echo    
    echo -e "  ${MAGENTA}-g, --geolocation${NC}\t\t${BOLD}OPTIONAL${NC}. Display the geo-coordinates of the IP address."
    echo    
    echo -e "  ${MAGENTA}-f, --full${NC}\t\t\t${BOLD}OPTIONAL${NC}. Display all available information of the IP address."
    echo -e "\t\t\t\tThis option has the same effect as passing -i, -r, -c, -n, -z,"
    echo -e "\t\t\t\tand -g together."
    echo    
    echo -e "  ${MAGENTA}-o, --own${NC}\t\t\t${BOLD}OPTIONAL${NC}. Lookup information about the external IP (WAN IP)"
    echo -e "\t\t\t\tof the executing system. This option is only necessary if at"
    echo -e "\t\t\t\tleast one ${YELLOW}IP${NC} is passed to the script as an input parameter."
    echo    
    echo -e "  ${MAGENTA}-v, --verbose${NC}\t\t\t${BOLD}OPTIONAL${NC}. Debug mode. Display detailed status information"
    echo -e "\t\t\t\tfor each executed processing step. Without this option, only"
    echo -e "\t\t\t\tthe IP information is printed."
    echo
    echo -e "  ${MAGENTA}-vv, --ultraverbose${NC}\t\t${BOLD}OPTIONAL${NC}. Trace mode. Display extremely detailed status"
    echo -e "\t\t\t\tinformation for each executed processing step. Displays even"
    echo -e "\t\t\t\tmore information than -v | --verbose."
    echo    
    echo -e "If no ${YELLOW}IP${NC} is passed, the script looks up the information for the executing system's"
    echo -e "external IP (i.e., your own, current WAN IP)."
    echo
    echo -e "If no display options are passed, the IP, region, city, and nation will be printed."
    echo
    echo -e "Licensed under ${BOLD}CC BY-NC-ND 4.0${NC} (https://creativecommons.org/licenses/by-nc-nd/4.0/)"
}

#
# Validates an input parameter.
# 
# Input parameters:
#  - [1] : The name of the input parameter.
#  - [2] : The value of the input parameter.
#
function validateParam {

    PARAM_NAME=$1
    PARAM_VALUE=$2
    if [[ -z "$PARAM_VALUE" || "$PARAM_VALUE" == -* ]]
    then
        echo -e "${RED}Option \"$PARAM_NAME\" requires an argument.${NC}"
        exit 1
    fi
}

# Parse input parameters. 
while [[ $# -gt 0 ]]
do
    case $1 in
        -a|--apikey)
            validateParam $1 $2
            P_API_KEY_FILE="$2"
            shift 2
            ;;
        -t|--throttle)
            validateParam $1 $2
            P_THROTTLE_DELAY=$2
            shift 2
            ;;
        -i|--ip)
            P_SHOW_IP="Y"
            shift
            ;;
        -r|--region)
            P_SHOW_IP_REGION="Y"
            shift
            ;;
        -c|--city)
            P_SHOW_IP_CITY="Y"
            shift
            ;;
        -n|--nation)
            P_SHOW_IP_NATION="Y"
            shift
            ;;
        -z|--zipcode)
            P_SHOW_IP_ZIPCODE="Y"
            shift
            ;;
        -g|--geolocation)
            P_SHOW_IP_GEOLOCATION="Y"
            shift
            ;;
        -o|--own)
            P_IP_LIST+=("$LOOKUP_OWN_KEYWORD") # This keyword represents own IP
            shift
            ;;
        -f|--full)
            P_SHOW_IP="Y"
            P_SHOW_IP_REGION="Y"
            P_SHOW_IP_CITY="Y"
            P_SHOW_IP_NATION="Y"
            P_SHOW_IP_ZIPCODE="Y"
            P_SHOW_IP_GEOLOCATION="Y"
            shift
            ;;
        -v|--verbose)
            P_VERBOSE_MODE="Y"
            shift
            ;;
        -vv|--ultraverbose)
            P_VERBOSE_MODE="Y"
            P_ULTRA_VERBOSE_MODE="Y"
            shift
            ;;
        -h|--help)
            showHelp
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option '$1'. Use -h|--help for a list of all supported options.${NC}"
            exit 1
            ;;
        *)
            P_IP_LIST+=("$1")
            shift
            ;;
    esac
done

####################################################################################################
# Functions
####################################################################################################

#
# Writes a log message.
# 
# Input parameters:
#  - [1] : The log message
#
function logMessage {

    LOG_LINE=$1
    if [[ "$P_VERBOSE_MODE" == "Y" ]]
    then
        echo -e "$LOG_LINE"
    fi
}

#
# Load and validate ipinfo API key.
#
function loadApiKey {

    if [ "$P_API_KEY_FILE" != "" ]
    then
        if [ ! -e "$P_API_KEY_FILE" ]
        then
            echo -e "${RED}API key file does not exist:${NC} ${BLUE}$P_API_KEY_FILE${NC}"
            exit 1
        fi
        
        if [ ! -f "$P_API_KEY_FILE" ]
        then
            echo -e "${RED}Path is not a file:${NC} ${BLUE}$P_API_KEY_FILE${NC}"
            exit 1
        fi

        logMessage "${BLUE}[ INIT ]${NC} Reading API key from file: ${BLUE}$P_API_KEY_FILE${NC}"

        IPINFO_API_KEY=$(cat "$P_API_KEY_FILE" | egrep "[a-z0-9]+" | head -n 1)
        if [ "$IPINFO_API_KEY" == "" ]
        then
            echo -e "${RED}No valid API key found in file:${NC} ${BLUE}$P_API_KEY_FILE${NC}"
            exit 1
        fi

        logMessage "${BLUE}[ INIT ]${NC} ipinfo API key: ${YELLOW}$IPINFO_API_KEY${NC}"
    fi
}

# 
# Retrieves information for an IP address.
#
# Input parameters:
#  - [1] : The IP address to look up (optional). If not provided, the function determines the WAN IP
#          information of the executing system.
#
function lookup_ip {

    LOOKUP_IP=$1

    # Create curl command    
    LOOKUP_COMMAND="$LOOKUP_CURL_COMMAND $LOOKUP_URL"
    if [[ "$LOOKUP_IP" != "" ]]
    then
        LOOKUP_COMMAND="$LOOKUP_COMMAND/$LOOKUP_IP"
    fi

    if [[ "$IPINFO_API_KEY" != "" ]]
    then
        LOOKUP_COMMAND="$LOOKUP_COMMAND -H \"$LOOKUP_API_KEY_HEADER $IPINFO_API_KEY\""
    fi

    if [[ "$P_ULTRA_VERBOSE_MODE" == "Y" ]]
    then
        LOOKUP_COMMAND="$LOOKUP_COMMAND -v"
    else
        LOOKUP_COMMAND="$LOOKUP_COMMAND -s"
    fi
    
    logMessage "${BLUE}[LOOKUP]${NC} Request: ${YELLOW}$LOOKUP_COMMAND${NC}"

    # Execute curl command
    IP_INFO=$(eval "$LOOKUP_COMMAND")
    
    logMessage "${BLUE}[LOOKUP]${NC} Response: ${MAGENTA}$IP_INFO${NC}"

    if [[ -n "$IP_INFO" ]]
    then
    
        if [[ $(echo "$IP_INFO" | fgrep -c "\"error\"") != 0 ]]
        then
            ERROR_INFO="$(echo "$IP_INFO" | fgrep "\"error\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')"
            ERROR_MESSAGE="$(echo "$IP_INFO" | fgrep "\"message\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')"
        
            echo -e "${RED}Failed to lookup IP information: $ERROR_INFO $ERROR_MESSAGE"
            return
        fi
        
        if [[ $(echo "$IP_INFO" | fgrep -c "Moved Permanently") != 0 ]]
        then
            echo -e "${RED}Web endpoint for IP lookup has moved permanently, please contact the author or create an issue: ${BLUE}https://github.com/jynxified/ip-lookup/issues${NC}"
            echo -e "${RED}Message from server:${NC}"
            echo -e "${MAGENTA}$IP_INFO${NC}"
            exit 1
        fi
        
	    WAN_IP=$(echo "$IP_INFO" | fgrep "\"ip\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
	    IP_REGION=$(echo "$IP_INFO" | fgrep "\"region\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
	    IP_ZIPCODE=$(echo "$IP_INFO" | fgrep "\"postal\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
	    IP_CITY=$(echo "$IP_INFO" | fgrep "\"city\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
	    IP_NATION=$(echo "$IP_INFO" | fgrep "\"country\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
	    IP_GEOLOCATION=$(echo "$IP_INFO" | fgrep "\"loc\"" | sed -e 's/^.*: "//g' -e 's/".*$//g')
	    
	    IP_OUTPUT=""
	    
	    # Option: Display "IP" (-i)
	    if [[ "$P_SHOW_IP" == "Y" ]]
	    then
	        IP_OUTPUT="$WAN_IP"
	    fi
	    
	    # Option: Display "region" (-r)
	    if [[ "$P_SHOW_IP_REGION" == "Y" ]]
	    then
	        if [[ "$IP_OUTPUT" != "" ]]
	        then
	            IP_OUTPUT="$IP_OUTPUT${YELLOW}/"
	        else
    	        IP_OUTPUT="${YELLOW}"
	        fi
            IP_OUTPUT="$IP_OUTPUT$IP_REGION${NC}"
	    fi
	  
	    # Option: Display "ZIP code" (-z)
	    if [[ "$P_SHOW_IP_ZIPCODE" == "Y" ]]
	    then
	        if [[ "$IP_OUTPUT" != "" ]]
	        then
	            IP_OUTPUT="$IP_OUTPUT${BLUE}/"
	        else
	            IP_OUTPUT="${BLUE}"
	        fi
            IP_OUTPUT="$IP_OUTPUT$IP_ZIPCODE${NC}"
	    fi
	    
	    # Option: Display "city" (-c)
	    if [[ "$P_SHOW_IP_CITY" == "Y" ]]
	    then
	        if [[ "$IP_OUTPUT" != "" ]]
	        then
	            IP_OUTPUT="$IP_OUTPUT${BLUE}/"
	        else
	            IP_OUTPUT="${BLUE}"
	        fi
            IP_OUTPUT="$IP_OUTPUT$IP_CITY${NC}"
	    fi
	    
	    # Option: Display "nation" (-n)
	    if [[ "$P_SHOW_IP_NATION" == "Y" ]]
	    then
	        if [[ "$IP_OUTPUT" != "" ]]
	        then
	            IP_OUTPUT="$IP_OUTPUT${GREEN}/"
	        else
	            IP_OUTPUT="${GREEN}"
	        fi
            IP_OUTPUT="$IP_OUTPUT$IP_NATION${NC}"
	    fi
	    
	    # Option: Display "geo-location" (-g)
	    if [[ "$P_SHOW_IP_GEOLOCATION" == "Y" ]]
	    then
	        if [[ "$IP_OUTPUT" != "" ]]
	        then
	            IP_OUTPUT="$IP_OUTPUT${MAGENTA}/"
	        else
	            IP_OUTPUT="${MAGENTA}"
	        fi
            IP_OUTPUT="$IP_OUTPUT$IP_GEOLOCATION${NC}"
	    fi
	    
	    echo -e "$IP_OUTPUT"
    fi
}

####################################################################################################
# Main code
####################################################################################################

# If no options are specified for a particular output, the default settings are used.
if [[ "$P_SHOW_IP" == "N" && "$P_SHOW_IP_REGION" == "N" && "$P_SHOW_IP_CITY" == "N" && "$P_SHOW_IP_NATION" == "N" && "$P_SHOW_IP_ZIPCODE" == "N" && "$P_SHOW_IP_GEOLOCATION" == "N" ]]
then
    P_SHOW_IP="Y"
    P_SHOW_IP_REGION="Y"
    P_SHOW_IP_CITY="Y"
    P_SHOW_IP_NATION="Y"
    
    logMessage "${BLUE}[ INIT ]${NC} Using default output options [-i, -r, -c, -n]."
fi

# If no IPs are specified, the IP of the executing system will be looked up.
if [[ "${#P_IP_LIST[@]}" == 0 ]]
then
    P_IP_LIST+=("$LOOKUP_OWN_KEYWORD")
fi

loadApiKey

# Lookup IPs
START_TIME=$(date +%s)
PROCESSED_IPS_CNTR=0

NUM_IPS=${#P_IP_LIST[@]}

logMessage "${BLUE}[ INIT ]${NC} $NUM_IPS IP(s) provided for lookup."

for IP in "${P_IP_LIST[@]}"
do

    ((PROCESSED_IPS_CNTR++))

    lookup_ip "$IP"

    if [[ ($P_THROTTLE_DELAY > 0) && ("$PROCESSED_IPS_CNTR" != "$NUM_IPS") ]]
    then
        logMessage "${BLUE}[ WAIT ]${NC} Throttling lookup speed, waiting $P_THROTTLE_DELAY second(s)..."
        sleep $P_THROTTLE_DELAY
    fi

done

END_TIME=$(date +%s)
TIME_DIFF=$((END_TIME - START_TIME))

# Print results.
logMessage "${BLUE}[STATUS]${NC} ${BOLD}$PROCESSED_IPS_CNTR IP(s) processed, duration $(date -u -d "@$TIME_DIFF" +%H:%M:%S).${NC}"
