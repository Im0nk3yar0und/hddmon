#!/usr/bin/bash

# Author: Your Name
# Date:   2024-01-31
# Description: Disk health and temperature monitoring script using smartctl.
# Note: This script is provided under the terms of the MIT License and is free to use, modify, and distribute.


# Initialize line count
line_count=0

# Function to increment line count and pause if needed
increment_line_count() {
    ((line_count++))
    if [ $line_count -ge 30 ]; then
        read -p "Press Enter to continue..."
        line_count=0  # Reset line count after pausing
    fi
}


# Function to create a frame
create_frame() {
    local len=$1
    local char=$2
    printf -v frame "%${len}s" ""
    echo "${frame// /$char}"
}


# Define colors
red=$(tput setaf 124)
grey=$(tput setaf 245)
yellow=$(tput setaf 172)
green=$(tput setaf 2)
blue=$(tput setaf 24)
reset=$(tput sgr0)  # Reset all attributes, including blinking

# Add the ANSI escape sequence for blinking to the red color
blinking_red=$(tput setaf 1; tput blink)
blinking_grey=$(tput setaf 245; tput blink)


if [ $EUID -ne 0 ]; then
  echo "${blinking_red}This script must be run as root.${reset}"
  exit 1
fi


# Check if smartctl command is available
if ! command -v smartctl &> /dev/null; then
    echo -e "${blinking_red}Error: smartctl command not found. Please install smartmontools.${reset}"

    # Add a command to install smartctl
    create_frame 65 "="
    echo -e "${yellow}You can install smartmontools using the following command:${reset}"
    echo -e "${yellow}For Debian/Ubuntu:${reset} ${grey} sudo apt-get install smartmontools${reset}"
    echo -e "${yellow}For Red Hat/Fedora:${reset} ${grey}sudo dnf install smartmontools${reset}"
    echo -e "${yellow}For Arch Linux:${reset} ${grey}    sudo pacman -S smartmontools${reset}"

    exit 1
fi


# Check if nvme command is available
if ! command -v nvme &> /dev/null; then
    echo -e "${blinking_red}Error: nvme command not found. Please install nvme-cli.${reset}"

    # Add a command to install nvme-cli
    create_frame 55 "="
    echo -e "${yellow}You can install nvme-cli using the following command:${reset}"
    echo -e "${yellow}For Debian/Ubuntu:${reset} ${grey} sudo apt-get install nvme-cli${reset}"
    echo -e "${yellow}For Red Hat/Fedora:${reset} ${grey}sudo dnf install nvme-cli${reset}"
    echo -e "${yellow}For Arch Linux:${reset} ${grey}    sudo pacman -S nvme-cli${reset}"

    exit 1
fi



# Function to display help message
function show_help() {
    echo "${grey}Usage:${reset}${green} $0 [-a] [-d] [-n] [-h] [-w] [-i]${reset}"
    echo "${grey}Options:${reset}"
    echo "  -a${reset}    ${grey}Display temperatures of all disks${reset}"
    echo "  -d${reset}    ${grey}Display HDD temperature${reset}"
    echo "  -n${reset}    ${grey}Display NVMe temperature${reset}"
    echo "  -w${reset}    ${grey}Watchdisk: Display HDD temperature continuously${reset}"
    echo "  -i${reset}    ${grey}Display author information${reset}"
    echo "  -h${reset}    ${grey}Display this help message${reset}"
    exit 1
}

# Default app 
SMARTCTL=/usr/sbin/smartctl


function author_info() {
    # Print script information
    echo ""
    create_frame 75 "${blue}=${reset}"
    printf "${blue}%-17s${reset} %-15s\n" "Author: " "Im0nk3yar0und"
    printf "${blue}%-17s${reset} ${grey}%-15s\n${reset}" "Date: " "2024-01-31"
    printf "${blue}%-17s${reset} ${grey}%-15s\n${reset}" "Description: " "Disk health and temperature monitoring script using smartctl."
    create_frame 75 "${blue}=${reset}"
    echo ""
}


function header_func() {
    # Print table headers
    printf "\n"
    create_frame 70 "="
    printf "         DISK                       HEALTH               TEMP\n"
    create_frame 70 "="
}



# Function to display HDD temperature
function hddtemp_func() {

    # Returns a list of disks.
    DISKS=$(lsblk -r -n -o NAME --nodeps | grep -v nvme)

    for DISK in ${DISKS}
    do
      TEMP=$(sudo ${SMARTCTL} -A /dev/${DISK} | grep "Celsius" | awk '{print $10}')
      HEALTH=$(sudo ${SMARTCTL} -H /dev/${DISK} | grep 'test result:' | cut -d: -f2 | sed 's/^[ \t]*//')

      # Uncomment the lines below if you want to use fixed values for testing
      #TEMP=36
      #HEALTH="PASSED"

      if [ -n "${TEMP}" ]; then
        # Check if TEMP is a number
        if [[ "${TEMP}" =~ ^[0-9]+$ ]]; then
          # If TEMP is a number, apply color-coding based on temperature ranges
          if [ "${TEMP}" -lt 35 ]; then
            TEMP_COLOR="${green}${TEMP}${reset}"
          elif [ "${TEMP}" -ge 35 ] && [ "${TEMP}" -le 45 ]; then
            TEMP_COLOR="${yellow}${TEMP}${reset}"
          else
            TEMP_COLOR="${blinking_red}${TEMP}${reset}"
          fi
        else
          # If TEMP is not a number, set TEMP_COLOR to a default value
          TEMP_COLOR="${blinking_grey}NULL${reset}"
        fi

        case "${HEALTH}" in
          "PASSED")
            HEALTH_COLOR="${green}${HEALTH}${reset}"
            ;;
          "FAILED")
            HEALTH_COLOR="${blinking_red}${HEALTH}${reset}"
            ;;
          *)
            HEALTH_COLOR="${blinking_grey}NULL  ${reset}"
            ;;
        esac

        # Print disk information
        printf "| ${grey}%-15s${reset} ${yellow}%-12s${reset} | ${grey}%-10s${reset} ${grey}%-10s${reset} | ${grey}%-12s${reset} %-8s \n" "HDD drive: " "/dev/${DISK}" "HEALTH: " "${HEALTH_COLOR}" "TEMPERATURE: " "${TEMP_COLOR}"
        increment_line_count
      else
        case "${HEALTH}" in
          "PASSED")
            HEALTH_COLOR="${green}${HEALTH}${reset}"
            ;;
          "FAILED" | "UNKNOWN" | "N/A")
            HEALTH_COLOR="${blinking_red}${HEALTH}${reset}"
            ;;
          *)
            HEALTH_COLOR="${blinking_grey}NULL  ${reset}"
            ;;
        esac

        # Print disk information
        TEMP_COLOR="${blinking_grey}NULL${reset}"
        printf "| ${grey}%-15s${reset} ${yellow}%-12s${reset} | ${grey}%-10s${reset} ${grey}%-10s${reset} | ${grey}%-12s${reset} %-8s \n" "HDD drive: " "/dev/${DISK}" "HEALTH: " "${HEALTH_COLOR}" "TEMPERATURE: " "${TEMP_COLOR}"
        increment_line_count
      fi
    done
}

# Function to display NVMe temperature
function nvmetemp_func() {

    # List all NVMe drives
    NVME_DRIVES=$(nvme list | awk '/\// {print $1}')

    for DRIVE in ${NVME_DRIVES}
    do
      TEMP=$(nvme smart-log ${DRIVE} | grep "temperature" | awk '{print $3}')
      WARNING=$(nvme smart-log ${DRIVE} | grep "critical_warning" | awk '{print $3}')
      
      # Uncomment the lines below if you want to use fixed values for testing
      #TEMP=35
      #WARNING=0

      if [ -n "${TEMP}" ]; then
        # Check if TEMP is a number
        if [[ "${TEMP}" =~ ^[0-9]+$ ]]; then
          if [ "${TEMP}" -lt 35 ]; then
            TEMP_COLOR="${green}${TEMP}${reset}"
          elif [ "${TEMP}" -ge 35 ] && [ "${TEMP}" -le 45 ]; then
            TEMP_COLOR="${yellow}${TEMP}${reset}"
          else
            TEMP_COLOR="${blinking_red}${TEMP}${reset}"
          fi
        else
          # If TEMP is not a number, set TEMP_COLOR to a default value
          TEMP_COLOR="${blinking_grey}NULL${reset}"
        fi
      else
        # If TEMP is not available, set TEMP_COLOR to a default value
        TEMP_COLOR="${blinking_grey}NULL${reset}"
      fi

      if [ -n "${WARNING}" ]; then
        # Check if WARNING is a number
        if [[ "${WARNING}" =~ ^[0-9]+$ ]]; then
          if [ "${WARNING}" -le 0 ]; then
            WARNING_COLOR="${green}PASSED${reset}"
          else
            WARNING_COLOR="${blinking_red}FAILED${reset}"
          fi
        else
          # If WARNING is not a number, set WARNING_COLOR to a default value
          WARNING_COLOR="${blinking_grey}NULL${reset}  "
        fi
      else
        # If WARNING is not available, set WARNING_COLOR to a default value
        WARNING_COLOR="${blinking_grey}NULL${reset}  "
      fi

      # Print drive information
      printf "| ${grey}%-15s${reset} ${yellow}%-12s${reset} | ${grey}%-10s${reset} ${grey}%-10s${reset} | ${grey}%-12s${reset} %-8s \n" "NVME drive: " "${DRIVE}" "HEALTH: " "${WARNING_COLOR}"  "TEMPERATURE: " "${TEMP_COLOR}"
      increment_line_count
    done
}

# Function to watch HDD and NVMe temperature continuously
function watchdisk_func() {
    while true; do
        clear
        header_func
        hddtemp_func
        footer_func
        sleep 5  # Adjust the sleep duration as needed
    done
}


function footer_func() {
    # Print end of the table
    create_frame 70 "="
}


# Default behavior when no arguments are provided
function default_behavior() {
    header_func
    hddtemp_func
    nvmetemp_func
    footer_func
}


# Parse command line options
while getopts ":adnhwi" opt; do
    case ${opt} in
        a)
            default_behavior
            exit 0
            ;;
        d)
            header_func
            hddtemp_func
            footer_func
            exit 0
            ;;
        n)
            header_func
            nvmetemp_func
            footer_func
            exit 0
            ;;
        h)
            show_help
            ;;
        w)
            watchdisk_func
            ;;
        i)
            author_info
            exit 0
            ;;
        \?)
            echo ""
            echo -e "\033[4m${red}Invalid option:${reset} -$OPTARG\033[0m" >&2
            echo ""
            show_help
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            ;;
    esac
done

# If no arguments are provided, run default behavior
default_behavior
