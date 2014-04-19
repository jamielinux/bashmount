#!/bin/bash

#=============================================================================#
#        FILE: bashmount                                                      #
#     VERSION: 3.2.0                                                          #
# DESCRIPTION: bashmount is a menu-driven bash script that can use different  #
#              backends to easily mount, unmount or eject removable devices   #
#              without dependencies on udisks or any GUI. An extensive        #
#              configuration file allows many aspects of the script to be     #
#              modified and custom commands to be run on devices.             #
#     LICENSE: GPLv2                                                          #
#     AUTHORS: Jamie Nguyen <j@jamielinux.com>                                #
#              Lukas B.                                                       #
#=============================================================================#

# Copyright (C) 2013-2014 Jamie Nguyen <j@jamielinux.com>
# Copyright (C) 2014 Lukas B.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License v2 as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

declare -r VERSION='3.2.0'

if (( $# > 0 )); then
    if [[ "${1}" = '-V' || "${1}" = '--version' ]]; then
        cat << EOF
bashmount ${VERSION}
Copyright (C) 2013-2014 Jamie Nguyen <j@jamielinux.com>
Copyright (C) 2014 Lukas B.
License GPLv2: GNU GPL version 2 <http://www.gnu.org/licenses/gpl-2.0.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Jamie Nguyen and Lukas B.
EOF
        exit 0
    else
        printf '%s\n' 'bashmount: invalid option.'
        exit 64
    fi
fi

#-------------------------------------#
#           CONFIGURATION             #
#-------------------------------------#
# {{{
# Make sure that user defined options will not interfere with grep.
unset GREP_OPTIONS

# Set defaults.
declare udisks='auto'
declare default_mount_options='--options nosuid,noexec,noatime'
declare -i show_internal=1
declare -i show_removable=1
declare -i show_optical=1
declare -i show_commands=1
declare -i show_full_device_names=0
declare -i colourize=1
declare -i custom4_show=0
declare -i custom5_show=0
declare -i custom6_show=0
declare -i run_post_mount=0
declare -i run_post_unmount=0
declare -a blacklist=()

mount_command() {
    if (( udisks == 0 )); then
        read -r -e -p 'Choose the mountpoint directory: ' dir
        while [[ ! -d "${dir}" ]] || findmnt "${dir}" >/dev/null 2>&1; do
            error 'No such directory, or mountpoint is already in use.'
            read -r -e -p 'Choose the mountpoint directory: ' dir
        done
        mount ${mount_options} "${1}" "${dir}"
    else
        udisksctl mount ${mount_options} --block-device "${1}"
    fi
}

unmount_command() {
    if (( udisks == 0 )); then
        umount "${1}"
    else
        udisksctl unmount --block-device "${1}"
    fi
}

filemanager() {
    cd "${1}" && "$SHELL"
    exit 0
}

post_mount() {
    error "No command specified in 'bashmount.conf'."
    return 1
}

post_unmount() {
    error "No command specified in 'bashmount.conf'."
    return 1
}

# Load configuration file.
declare CONFIGFILE=

if [[ -z "${XDG_CONFIG_HOME}" ]]; then
    CONFIGFILE="${HOME}/.config/bashmount/config"
else
    CONFIGFILE="${XDG_CONFIG_HOME}/bashmount/config"
fi

if [[ ! -f "${CONFIGFILE}" ]]; then
    CONFIGFILE='/etc/bashmount.conf'
fi

if [[ -f "${CONFIGFILE}" ]]; then
    if ! . "${CONFIGFILE}"; then
        printf '%s\n' 'bashmount: Failed to source configuration file.'
        exit 78
    fi
fi

if [[ "${udisks}" == "auto" ]]; then
    type -p udisksctl >/dev/null 2>&1 && udisks=1 || udisks=0
elif  (( udisks == 1 )); then
    if ! type -p udisksctl >/dev/null 2>&1; then
        printf '%s\n' "bashmount: 'udisksctl': command not found"
        exit 69
    fi
fi

if ! type -p lsblk >/dev/null 2>&1; then
    printf '%s\n' "bashmount: 'lsblk': command not found"
    exit 69
fi

declare mount_options="${default_mount_options}"
# }}}

#-------------------------------------#
#         GENERAL FUNCTIONS           #
#-------------------------------------#
# {{{
unset ALL_OFF BOLD BLUE GREEN RED
if (( colourize )); then
    if tput setaf 0 >/dev/null 2>&1; then
        ALL_OFF="$(tput sgr0)"
        BOLD="$(tput bold)"
        BLUE="${BOLD}$(tput setaf 4)"
        GREEN="${BOLD}$(tput setaf 2)"
        RED="${BOLD}$(tput setaf 1)"
    else
        ALL_OFF='\e[1;0m'
        BOLD='\e[1;1m'
        BLUE="${BOLD}\e[1;34m"
        GREEN="${BOLD}\e[1;32m"
        RED="${BOLD}\e[1;31m"
    fi
    readonly ALL_OFF BOLD BLUE GREEN RED
fi

msg() {
    printf '%s\n' "${GREEN}==>${ALL_OFF}${BOLD} ${@}${ALL_OFF}" >&2
}

error() {
    printf '%s\n' "${RED}==>${ALL_OFF}${BOLD} ERROR: ${@}${ALL_OFF}" >&2
}

print_commands() {
    print_separator_commands
    printf '%s' "${BLUE}e${ALL_OFF}: eject   ${BLUE}i${ALL_OFF}: info"
    printf '%s' "   ${BLUE}m${ALL_OFF}: mount   ${BLUE}o${ALL_OFF}: open"
    printf '%s\n\n' "   ${BLUE}u${ALL_OFF}: unmount"
    printf '%s' "${BLUE}a${ALL_OFF}: unmount all"
    printf '%s' "   ${BLUE}r${ALL_OFF}: refresh"
    printf '%s\n\n' "   ${BLUE}q${ALL_OFF}: quit   ${BLUE}?${ALL_OFF}: help"
}

print_submenu_commands() {
    print_separator_commands
    printf '%s' "${BLUE}e${ALL_OFF}: eject   ${BLUE}i${ALL_OFF}: info"
    if info_mounted "${devname}"; then
        printf '%s' "   ${BLUE}u${ALL_OFF}: unmount"
    else
        printf '%s' "   ${BLUE}m${ALL_OFF}: mount"
    fi
    printf '%s\n\n' "   ${BLUE}o${ALL_OFF}: open"
    printf '%s' "${BLUE}b${ALL_OFF}: back   ${BLUE}r${ALL_OFF}: refresh"
    printf '%s\n' "   ${BLUE}q${ALL_OFF}: quit   ${BLUE}?${ALL_OFF}: help"

    printf '\n'
    printf '%s' "${BLUE}1${ALL_OFF}: read-only"
    printf '%s' "   ${BLUE}2${ALL_OFF}: luksOpen"
    printf '%s' "   ${BLUE}3${ALL_OFF}: luksClose"
    printf '\n'

    if (( custom4_show )) || (( custom5_show )) || (( custom6_show )); then
        printf '\n'
    fi

    if (( custom4_show )) && [[ -n "${custom4_desc}" ]]; then
        printf '%s' "${BLUE}4${ALL_OFF}: ${custom4_desc}"
    fi

    if (( custom5_show )) && [[ -n "${custom5_desc}" ]]; then
        printf '%s' "   ${BLUE}5${ALL_OFF}: ${custom5_desc}"
    fi

    if (( custom6_show )) && [[ -n "${custom6_desc}" ]]; then
        printf '%s' "   ${BLUE}6${ALL_OFF}: ${custom6_desc}"
    fi

    if (( custom4_show )) || (( custom5_show )) || (( custom6_show )); then
        printf '\n'
    fi
}

enter_to_continue() {
    printf '\n'
    read -r -e -p "Press [${BLUE}enter${ALL_OFF}] to continue: " null
}

invalid_command() {
    printf '\n'
    error 'Invalid command. See the help menu.'
    enter_to_continue
}

print_separator() {
    printf '%s\n\n' '====================================================='
}

print_separator_commands() {
    printf '%s\n\n' '===================== COMMANDS ======================'
}

print_separator_device() {
    printf '%s\n\n' '==================== DEVICE MENU ===================='
}

print_separator_optical() {
    printf '%s\n\n' '=================== OPTICAL MEDIA ==================='
}

print_separator_removable() {
    printf '%s\n\n' '================== REMOVABLE MEDIA =================='
}

print_separator_internal() {
    printf '%s\n\n' '================== INTERNAL MEDIA ==================='
}

print_help() {
    clear
    print_commands
    print_separator
    printf '%s' "${GREEN}==>${ALL_OFF} "
    printf '%s' "${BOLD}To mount the first device, enter ${ALL_OFF}"
    printf '%s' "${BLUE}1m${ALL_OFF}"
    printf '%s\n\n' "${BOLD}.${ALL_OFF}"
    printf '%s' "${GREEN}==>${ALL_OFF} "
    printf '%s\n\n' "${BOLD}To open the mountpath directory of the first${ALL_OFF}"
    printf '%s' "${BOLD}    device (mounting if required), enter "
    printf '%s' "${BLUE}1o${ALL_OFF}"
    printf '%s\n\n' "${BOLD}.${ALL_OFF}"
    printf '%s' "${GREEN}==>${ALL_OFF} "
    printf '%s' "${BOLD}To view a device sub-menu, "
    printf '%s\n\n' "just enter the number.${ALL_OFF}"
    printf '%s' "${GREEN}==>${ALL_OFF} "
    printf '%s' "${BLUE}a${ALL_OFF}"
    printf '%s' "${BOLD}, "
    printf '%s' "${BLUE}r${ALL_OFF}"
    printf '%s' "${BOLD}, "
    printf '%s' "${BLUE}q${ALL_OFF} "
    printf '%s' "${BOLD}and "
    printf '%s' "${BLUE}?${ALL_OFF} "
    printf '%s\n\n' "${BOLD}do not require a number.${ALL_OFF}"
    print_separator
    enter_to_continue
}

print_help_sub() {
    clear
    print_submenu_commands
    printf '\n'
    print_separator
    printf '%s' "${GREEN}==>${ALL_OFF} "
    printf '%s\n\n' "${BOLD}To perform a command, enter a character.${ALL_OFF}"
    printf '%s' "${GREEN}==>${ALL_OFF} "
    printf '%s' "${BOLD}For example, to mount this device, enter ${ALL_OFF}"
    printf '%s' "${BLUE}m${ALL_OFF}"
    printf '%s\n\n' "${BOLD}.${ALL_OFF}"
    print_separator
    enter_to_continue
}

print_device_name() {
    # The padding between device location and device label.
    local -i padding=22
    # For device names that are too long, this defines how many characters from
    # the end of the string we will show.
    local -i post_length=6

    info_label="$(info_fslabel "${devname}")"
    if [[ -z "${info_label}" ]]; then
        if [[ "${1}" == 'optical' ]]; then
            info_label="$(lsblk -dno MODEL "${devname}")"
        else
            info_label="$(info_partlabel "${devname}")"
        fi
        [[ -z "${info_label}" ]] && info_label='No label'
    fi

    listed[device_number]="${devname}"
    (( device_number++ ))

    printf '%s' " ${BLUE}${device_number})${ALL_OFF}"
    devnameshort="${devname##*/}"

    if (( !show_full_device_names )) && (( ${#devnameshort} > padding )); then
        pre_length=$(( padding - post_length - 3 ))
        devnamepre="${devnameshort:0:pre_length}"
        devnamepost="${devnameshort:${#devnameshort}-post_length}"
        devnameshort="${devnamepre}...${devnamepost}"
    fi

    printf '%s' " ${devnameshort}:"

    # Add padding between device location and device label.
    devname_length="${#devnameshort}"
    for (( i=padding ; i>devname_length ; i-- )); do
        printf '%s' " "
    done

    printf '%s' " ${info_label}"
    if info_mounted "${devname}"; then
        printf '%s' " ${GREEN}[mounted]${ALL_OFF}"
        mounted[${#mounted[*]}]="${devname}"
    fi
    printf '\n'
}

# }}}

#-------------------------------------#
#       INFORMATION RETRIEVAL         #
#-------------------------------------#
# {{{
# Returns 0 if the device is registered as removable device in the kernel,
# otherwise it returns 1.
info_removable() {
    [[ "$(lsblk -drno RM "${1}")" == '1' ]]
}

# Prints the device type, for example partition or disk.
info_type() {
    lsblk -drno TYPE "${1}"
}

# Prints the filesystem label, if present.
info_fslabel() {
    lsblk -drno LABEL "${1}"
}

# Prints the partition label, if present.
info_partlabel() {
    lsblk -drno PARTLABEL "${1}"
}

# Prints the mountpath, if mounted.
info_mountpath() {
    findmnt -no TARGET "${1}"
}

# Returns 0 if the device is mounted, 1 otherwise.
info_mounted() {
    findmnt -no TARGET "${1}" >/dev/null 2>&1
}

# Prints the filesystem type.
info_fstype() {
    lsblk -drno FSTYPE "${1}"
}

# Prints the device size.
info_size() {
    lsblk -drno SIZE "${1}"
}
# }}}

#-------------------------------------#
#        DEVICE MANIPULATION          #
#-------------------------------------#
# {{{
check_device() {
    if [[ ! -b "${1}" ]]; then
        printf '\n'
        error "${1} is no longer available."
        enter_to_continue
        return 1
    fi
    return 0
}

action_eject() {
    check_device "${1}" || return 1
    info_mounted "${1}" && action_unmount "${1}"
    if ! info_mounted "${1}"; then
        printf '\n'
        msg "Ejecting ${1} ..."
        printf '\n'
        eject "${1}"
        # Give the device some time to eject. If we don't then sometimes the ejected
        # device will still be present when returning to the main menu.
        enter_to_continue
        sleep 2
    fi
}

action_info() {
    check_device "${1}" || return 1
    lsblk -o NAME,FSTYPE,MOUNTPOINT,SIZE "${1}" | less
}

action_mount() {
    check_device "${1}" || return 1
    printf '\n'
    if info_mounted "${1}"; then
        error "${1} is already mounted."
    else
        msg "Mounting ${1} ..."
        if mount_command "${1}"; then
            msg "${1} mounted succesfullly."
            (( run_post_mount )) && post_mount "${1}"
        else
            printf '\n'
            error "${1} could not be mounted."
        fi
    fi
    enter_to_continue
}

action_open() {
    if ! info_mounted "${1}"; then
        printf '\n'
        msg "Mounting ${1} ..."
        if mount_command "${1}"; then
            msg "${1} mounted succesfullly."
            (( run_post_mount )) && post_mount "${1}"
        else
            printf '\n'
            error "${1} could not be mounted."
            enter_to_continue
            return 1
        fi
    fi
    printf '\n'
    msg "Opening ${1} ..."
    printf '\n'
    filemanager "$(info_mountpath "${1}")"
    enter_to_continue
}

action_unmount() {
    printf '\n'
    if info_mounted "${1}"; then
        msg "Unmounting ${1} ..."
        printf '\n'
        if unmount_command "${1}"; then
            msg "${1} unmounted successfully."
            (( run_post_unmount )) && post_unmount "${1}"
        else
            printf '\n'
            error "${1} could not be unmounted."
        fi
    else
        error "${1} is not mounted."
    fi
    enter_to_continue
}
# }}}

#-------------------------------------#
#           MENU FUNCTIONS            #
#-------------------------------------#
# {{{
list_devices() {
    local -a all=() removable=() internal=() optical=()
    # The array "all" contains the sorted list of devices returned by lsblk.
    all=( $(lsblk -plno NAME) )
    # The array "listed" contains all devices that are shown to the user.
    listed=()
    # The array "mounted" contains all devices that are listed and mounted.
    mounted=()
    # "device_number" is the total number of devices listed and equals ${#listed[*]}.
    device_number=0

    for devname in ${all[@]}; do
        local info_type=
        # Hide blacklisted devices.
        for string in ${blacklist[@]}; do
            lsblk -dPno NAME,TYPE,FSTYPE,LABEL,MOUNTPOINT,PARTLABEL "${devname}" \
                | grep -E "${string}" >/dev/null 2>&1
            (( $? )) || continue 2
        done
        info_type=$(info_type "${devname}")
        # Sort devices into arrays removable, internal, and optical.
        if [[ "${info_type}" == 'part' || "${info_type}" == 'crypt' ]]; then
            if info_removable "${devname}"; then
                removable[${#removable[*]}]="${devname}"
            else
                internal[${#internal[*]}]="${devname}"
            fi
        # Normally we don't want to see a 'disk', but if it has no partitions
        # (eg, internal storage on some portable media devices) then it should
        # be visible.
        elif [[ "${info_type}" == 'disk' ]]; then
            [[ "${all[@]}" =~ ${devname}1 ]] && continue
            if info_removable "${devname}"; then
                removable[${#removable[*]}]="${devname}"
            else
                internal[${#internal[*]}]="${devname}"
            fi
        elif [[ "${info_type}" == 'rom' ]]; then
            optical[${#optical[*]}]="${devname}"
        else
            continue
        fi
    done
    # Print output.
    # List internal media.
    if (( show_internal )) && (( ${#internal[*]} )); then
        print_separator_internal
        for devname in ${internal[@]}; do
            print_device_name
        done
        printf '\n'
    fi
    # List removable media.
    if (( show_removable )) && (( ${#removable[*]} )); then
        print_separator_removable
        for devname in ${removable[@]}; do
            print_device_name
        done
        printf '\n'
    fi
    # List optical media.
    if (( show_optical )) && (( ${#optical[*]} )); then
        print_separator_optical
        for devname in ${optical[@]}; do
            print_device_name optical
        done
        printf '\n'
    fi
    (( device_number )) || printf '%s\n' 'No devices.'
}

submenu() {
    check_device "${devname}" || return 1
    local info_label= info_fstype= info_size=
    info_label="$(info_fslabel "${devname}")"
    if [[ -z "${info_label}" ]]; then
        info_label="$(info_partlabel "${devname}")"
        if [[ -z "${info_label}" ]]; then
            info_label='-'
        fi
    fi
    info_fstype="$(info_fstype "${devname}")"
    info_size="$(info_size "${devname}")"
    clear
    print_separator_device
    printf '%s\n' "device    : ${devname}"
    printf '%s\n' "label     : ${info_label}"
    printf '%s' 'mounted   : '
    if info_mounted "${devname}"; then
        printf '%s\n' "${GREEN}yes${ALL_OFF}"
        printf '%s\n' "mountpath : $(info_mountpath "${devname}")"
    else
        printf '%s\n' "${RED}no${ALL_OFF}"
    fi
    printf '%s\n' "fstype    : ${info_fstype}"
    printf '%s\n' "size      : ${info_size}"
    if (( show_commands )); then
        printf '\n'
        print_submenu_commands
    fi
    printf '\n'
    print_separator
    read -r -e -p 'Command: ' action
    case "${action}" in
        'e') action_eject "${devname}";;
        'i') action_info "${devname}";;
        'm') action_mount "${devname}";;
        'o') action_open "${devname}";;
        'u') action_unmount "${devname}";;
        'b') return 1;;
        'r') return 0;;
        'q') exit;;
        '?')
            print_help_sub
            return 0;;
        '1')
            printf '\n'
            msg 'Mounting read-only ...'
            printf '\n'
            mount_options="${default_mount_options}"' --read-only'
            mount_command "${devname}"
            mount_options="${default_mount_options}"
            enter_to_continue
            return 0;;
        '2')
            printf '\n'
            msg 'Opening luks volume ...'
            printf '\n'
            if (( udisks == 0 )); then
                cryptsetup open --type luks -v "${devname}" "luks-${devname##*/}"
            else
                udisksctl unlock --block-device "${devname}"
            fi
            enter_to_continue
            return 0;;
        '3')
            printf '\n'
            msg 'Closing luks volume ...'
            printf '\n'
            if (( udisks == 0 )); then
                cryptsetup close --type luks "${devname}"
            else
                udisksctl lock --block-device "${devname}"
            fi
            enter_to_continue
            return 0;;
        '4')
            if (( custom4_show )); then
                printf '\n'
                msg "Running custom command ${custom4_desc} ..."
                printf '\n'
                custom4_command "${devname}"
                enter_to_continue
            else
                invalid_command
            fi
            return 0;;
        '5')
            if (( custom5_show )); then
                printf '\n'
                msg "Running custom command ${custom5_desc} ..."
                printf '\n'
                custom5_command "${devname}"
                enter_to_continue
            else
                invalid_command
            fi
            return 0;;
        '6')
            if (( custom6_show )); then
                printf '\n'
                msg "Running custom command ${custom6_desc} ..."
                printf '\n'
                custom6_command "${devname}"
                enter_to_continue
            else
                invalid_command
            fi
            return 0;;
         *) invalid_command
            return 0;;
    esac
}

select_action() {
    local devname= letter=
    local -i number=
    print_separator
    read -r -e -p 'Command: ' action
    if [[ "${action}" =~ ^[1-9] ]]; then
        if [[ "${action}" =~ ^[1-9][0-9]*$ ]]; then
            number="$(( action - 1 ))"
            if (( number >= device_number )); then
                invalid_command
                return 1
            fi
            devname=${listed[number]}
            while :; do
                submenu || break
            done
        elif [[ "${action}" =~ ^[1-9][0-9]*[eimou]$ ]]; then
            number="$(( ${action%?} - 1 ))"
            letter="${action: -1}"
            if (( number >= device_number )); then
                invalid_command
                return 1
            fi
            devname="${listed[number]}"
            case "${letter}" in
                'e') action_eject "${devname}";;
                'i') action_info "${devname}";;
                'm') action_mount "${devname}";;
                'o') action_open "${devname}";;
                'u') action_unmount "${devname}";;
                 *)  return 1;;
            esac
            return 0
        else
            invalid_command
            return 1
        fi
    else
        case "${action}" in
            'a')
                printf '\n'
                if (( ! ${#mounted[*]} )); then
                    error 'No devices mounted.'
                    enter_to_continue
                    return 1
                fi
                read -r -e -p 'Unmount all devices [y/N]?: ' unmount
                if [[ "${unmount}" != 'y' ]] && [[ "${unmount}" != 'Y' ]]; then
                    return 0
                fi
                clear
                for devname in ${mounted[@]}; do
                    action_unmount "${devname}" || continue
                done
                enter_to_contine
                return 1;;
            'r'|"")
                return 0;;
            'q'|'b')
                exit 0;;
            '?')
                print_help
                return 0;;
            *)
                invalid_command
                return 1;;
        esac
    fi
}
# }}}

declare -i device_number=
declare -a mounted=()
declare -a listed=()

while true; do
    clear
    list_devices
    (( show_commands )) && print_commands
    select_action
done
