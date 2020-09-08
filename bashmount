#!/bin/bash
set -u

declare -r VERSION="4.3.2"

#=============================================================================#
#        FILE: bashmount                                                      #
#     WEBSITE: https://github.com/jamielinux/bashmount                        #
# DESCRIPTION: bashmount is a menu-driven bash script that can use different  #
#              backends to easily mount, unmount or eject removable devices   #
#              without dependencies on any GUI. An extensive configuration    #
#              file allows many aspects of the script to be modified and      #
#              custom commands to be run on devices.                          #
#     LICENSE: GPLv2                                                          #
#     AUTHORS: Jamie Nguyen <j@jamielinux.com>                                #
#              Lukas B.                                                       #
#=============================================================================#

# Copyright (C) 2013-2020 Jamie Nguyen <j@jamielinux.com>
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

if (( $# > 0 )) && [[ "$1" == "-v" || "$1" == "--version" ]]; then
    printf '%s\n' "$VERSION"
    exit 0
fi

declare -ri EXIT_CMDNOTFOUND=127
declare -ri EXIT_CONFIG=78

# {{{ ··· CONFIGURATION
# Make sure that user defined options will not interfere with grep.
unset GREP_OPTIONS

# Set defaults.
declare udisks="auto"
declare mount_options=""
declare -i show_internal=1
declare -i show_removable=1
declare -i show_optical=1
declare -i show_commands=1
declare -i colourize=1
declare -i pretty=1
declare -i custom4_show=0
declare -i custom5_show=0
declare -i custom6_show=0
declare custom4_desc=""
declare custom5_desc=""
declare custom6_desc=""
declare -i run_post_mount=0
declare -i run_post_unmount=0
declare -a exclude=()

# Backwards compat
declare default_mount_options=""
declare -a blacklist=()

filemanager() {
    ( cd "$1" && "$SHELL" )
}

post_mount() {
    error "No 'post_mount' command specified in bashmount configuration file."
    return 1
}

post_unmount() {
    error "No 'post_unmount' command specified in bashmount configuration file."
    return 1
}

declare CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bashmount/config"
[[ ! -e "$CONFIG_FILE" ]] && CONFIG_FILE="/etc/bashmount.conf"
if [[ -e "$CONFIG_FILE" ]]; then
    if ! . "$CONFIG_FILE"; then
        printf '%s\n' "bashmount: Failed to source configuration file."
        exit $EXIT_CONFIG
    fi
fi

if [[ "$udisks" != 0 ]]; then
    if type -p udisksctl >/dev/null 2>&1; then
        [[ "$udisks" == "auto" ]] && udisks=1
    elif [[ "$udisks" == "auto" ]]; then
        udisks=0
    else
        printf '%s\n' "bashmount: 'udisksctl': command not found"
        exit $EXIT_CMDNOTFOUND
    fi
fi

if ! type -p lsblk >/dev/null 2>&1; then
    printf '%s\n' "bashmount: 'lsblk': command not found"
    exit $EXIT_CMDNOTFOUND
fi

# Backwards compat
[[ -n "$default_mount_options" ]] && mount_options="$default_mount_options"
(( ${#exclude[@]} == 0 )) && exclude=("${blacklist[@]}")
# }}}

# {{{ ··· PRINTING FUNCTIONS
if (( colourize )); then
    if tput setaf 0 >/dev/null 2>&1; then
        declare -r ALL_OFF="$(tput sgr0)"
        declare -r BOLD="$(tput bold)"
        declare -r BLUE="${BOLD}$(tput setaf 4)"
        declare -r GREEN="${BOLD}$(tput setaf 2)"
        declare -r RED="${BOLD}$(tput setaf 1)"
    else
        declare -r ALL_OFF="\e[1;0m"
        declare -r BOLD="\e[1;1m"
        declare -r BLUE="${BOLD}\e[1;34m"
        declare -r GREEN="${BOLD}\e[1;32m"
        declare -r RED="${BOLD}\e[1;31m"
    fi
else
    declare -r ALL_OFF="" BOLD="" BLUE="" GREEN="" RED=""
fi
declare -r ARROW="==>"

msg() {
    printf '\n%b\n\n' "${GREEN}${ARROW}${ALL_OFF}${BOLD} ${*}${ALL_OFF}" >&2
}
error() {
    printf '\n%b\n\n' "${RED}${ARROW}${BOLD} ERROR: ${*}${ALL_OFF}" >&2
    enter_to_continue
}
enter_to_continue() {
    printf '\n'
    read -r -e -p "Press [${BLUE}enter${ALL_OFF}] to continue: "
}
invalid_command() {
    printf '\n'
    error "Invalid command. See the help menu."
}

print_commands() {
    printf '\n\n'
    print_separator_commands
    printf '%s' " ${BLUE}e${ALL_OFF}: eject"
    printf '%s' "          ${BLUE}i${ALL_OFF}: info"
    printf '%s' "        ${BLUE}m${ALL_OFF}: mount"
    printf '%s' "        ${BLUE}o${ALL_OFF}: open"
    printf '%s' "        ${BLUE}u${ALL_OFF}: unmount"
    printf '\n\n'
    printf '%s' " ${BLUE}[Enter]${ALL_OFF}: refresh"
    printf '%s' "           ${BLUE}a${ALL_OFF}: unmount all"
    printf '%s' "        ${BLUE}q${ALL_OFF}: quit"
    printf '%s' "        ${BLUE}?${ALL_OFF}: help"
    printf '\n\n'
}

print_submenu_commands() {
    printf '\n\n'
    print_separator_commands
    printf '%s' " ${BLUE}e${ALL_OFF}: eject"
    printf '%s' "              ${BLUE}i${ALL_OFF}: info"
    if check_mounted "$devname"; then
        printf '%s' "               ${BLUE}u${ALL_OFF}: unmount"
    else
        printf '%s' "               ${BLUE}m${ALL_OFF}: mount  "
    fi
    printf '%s' "            ${BLUE}o${ALL_OFF}: open"
    printf '\n\n'
    printf '%s' " ${BLUE}[Enter]${ALL_OFF}: refresh"
    printf '%s' "      ${BLUE}b${ALL_OFF}: back"
    printf '%s' "               ${BLUE}q${ALL_OFF}: quit"
    printf '%s' "               ${BLUE}?${ALL_OFF}: help"
    printf '\n\n'
    printf '%s' " ${BLUE}1${ALL_OFF}: luksDump"
    printf '%s' "           ${BLUE}2${ALL_OFF}: luksOpen"
    printf '%s' "           ${BLUE}3${ALL_OFF}: luksClose"
    printf '\n'

    if (( custom4_show )) || (( custom5_show )) || (( custom6_show )); then
        local -i col_width=18
        printf '\n'
        (( custom4_show )) && [[ -n "$custom4_desc" ]] \
            && printf '%s' " ${BLUE}4${ALL_OFF}: $custom4_desc"
        local -i custom4_desc_len="${#custom4_desc}"
        if (( custom4_desc_len < col_width )); then
            for (( i=18; i>custom4_desc_len; i-- )); do
                printf '%s' " "
            done
        fi
        (( custom5_show )) && [[ -n "$custom5_desc" ]] \
            && printf '%s' " ${BLUE}5${ALL_OFF}: $custom5_desc"
        local -i custom5_desc_len="${#custom5_desc}"
        if (( custom5_desc_len < col_width )); then
            for (( i=18; i>custom5_desc_len; i-- )); do
                printf '%s' " "
            done
        fi
        (( custom6_show )) && [[ -n "$custom6_desc" ]] \
            && printf '%s' " ${BLUE}6${ALL_OFF}: $custom6_desc"
        printf '\n'
    fi
}

__print() {
    printf "${BOLD}"
    if (( pretty )); then
        printf '%s\n\n' "$1" | sed -e "s/-/━/g"
    else
        printf '%s\n\n' "$1"
    fi
    printf "${ALL_OFF}"
}
print_separator() {
    __print "-----------------------------------------------------------------------------"
}
print_separator_commands() {
    __print "--------------------------------  Commands  ---------------------------------"
}
print_separator_device() {
    __print "-------------------------------  Device Menu  -------------------------------"
}
print_separator_optical() {
    __print "------------------------------  Optical Media  ------------------------------"
}
print_separator_removable() {
    __print "-----------------------------  Removable Media  -----------------------------"
}
print_separator_internal() {
    __print "-----------------------------  Internal Media  ------------------------------"
}

print_help() {
    clear
    print_commands
    print_separator
    printf '%b' "  ${GREEN}${ARROW}${ALL_OFF}  "
    printf '%s' "${BOLD}To mount the first device, enter ${ALL_OFF}"
    printf '%s' "${BLUE}1m${ALL_OFF}${BOLD}.${ALL_OFF}"
    printf '\n\n'
    printf '%b' "  ${GREEN}${ARROW}${ALL_OFF}  "
    printf '%s' "${BOLD}To open the mountpath directory of the first${ALL_OFF}"
    printf '\n\n'
    printf '%s' "       ${BOLD}device (mounting if required), enter "
    printf '%s' "${BLUE}1o${ALL_OFF}${BOLD}.${ALL_OFF}"
    printf '\n\n'
    printf '%b' "  ${GREEN}${ARROW}${ALL_OFF}  "
    printf '%s' "${BOLD}To view a device sub-menu, just enter the number.${ALL_OFF}"
    printf '\n\n'
    printf '%b' "  ${GREEN}${ARROW}${ALL_OFF}  "
    printf '%s' "${BLUE}[Enter]${ALL_OFF}"
    printf '%s' "${BOLD}, "
    printf '%s' "${BLUE}a${ALL_OFF}"
    printf '%s' "${BOLD}, "
    printf '%s' "${BLUE}q${ALL_OFF} "
    printf '%s' "${BOLD}and "
    printf '%s' "${BLUE}?${ALL_OFF} "
    printf '%s' "${BOLD}do not require a number.${ALL_OFF}"
    printf '\n\n'
    print_separator
    enter_to_continue
}

print_help_submenu() {
    clear
    print_submenu_commands
    printf '\n'
    print_separator
    printf '%b' "  ${GREEN}${ARROW}${ALL_OFF}  "
    printf '%s' "${BOLD}To perform a command, enter a character and press ${ALL_OFF}"
    printf '%s' "${BLUE}[Enter]${ALL_OFF}${BOLD}.${ALL_OFF}"
    printf '\n\n'
    printf '%b' "  ${GREEN}${ARROW}${ALL_OFF}  "
    printf '%s' "${BOLD}For example, to mount this device, type ${ALL_OFF}"
    printf '%s' "${BLUE}m${ALL_OFF} and press ${BLUE}[Enter]${ALL_OFF}"
    printf '%s' "${BOLD}.${ALL_OFF}"
    printf '\n\n'
    print_separator
    enter_to_continue
}

print_device() {
    local -i padding_name=13
    local -i padding_label=18
    local -i padding_size=6

    local label="$(info_fslabel "$devname")"
    local fstype="$(info_fstype "$devname")"

    [[ -z "$label" ]] && (( $# == 1 )) && [[ "$1" == "optical" ]] \
        && label="$(lsblk -dno MODEL "$devname")"
    [[ -z "$label" ]] && label="$(info_partlabel "$devname")"
    [[ -z "$label" ]] && [[ "$fstype" == "crypto_LUKS" ]] && label="crypto_LUKS"
    [[ -z "$label" ]] && label="-"

    label="$(printf '%s' "$label" | sed -e 's/\\x20/ /g')"

    listed[device_number]="$devname"
    (( device_number++ ))

    printf '%s' " ${BLUE}${device_number})${ALL_OFF}"

    devname_short="${devname##*/}"
    label_short="$label"
    if (( ${#devname_short} > padding_name )); then
        len=$(( padding_name - 4 ))
        devname_short="${devname_short:0:len}..."
    elif (( ${#label} > padding_label )); then
        label_len=$(( padding_label - 4 ))
        label_short="${label:0:label_len}..."
    fi

    printf '%s' " ${devname_short}:"
    for (( i=padding_name; i>${#devname_short}; i-- )); do
        printf '%s' " "
    done

    printf '%s' " $label_short"
    for (( i=padding_label; i>${#label_short}; i-- )); do
        printf '%s' " "
    done

    size="$(info_size "$devname")"
    printf '%s' " $size"
    if (( ${#size} < padding_size )); then
        for (( i=padding_size; i>${#size}; i-- )); do
            printf '%s' " "
        done
    fi

    if [[ "$fstype" == "crypto_LUKS" ]]; then
        local uuid="$(info_uuid "$devname")"
        if [[ -n "$uuid" ]]; then
            for dev in "${all[@]}"; do
                if [[ "$dev" == "/dev/mapper/luks-$uuid" ]]; then
                    printf '%s' " ${GREEN}decrypted [luks-${uuid:0:4}...]${ALL_OFF}"
                fi
            done
        fi
    elif check_mounted "$devname"; then
        mountpath="$(info_mountpath "$devname")"
        printf '%s' " ${GREEN}[$mountpath]${ALL_OFF}"
        mounted[${#mounted[*]}]="$devname"
    fi
    printf '\n'
}
# }}}

# {{{ ··· INFORMATION RETRIEVAL
# Returns 0 (ie, success) if the device still exists. Otherwise it returns 1.
check_device() {
    if [[ ! -b "$1" ]]; then
        error "$1 is no longer available."
        return 1
    fi
}
# Returns 0 (ie, success) if the device is mounted. Otherwise it returns 1.
check_mounted() {
    findmnt -no TARGET "$1" >/dev/null 2>&1
}
# Returns 0 (ie, success) if the device is registered as a removable device in
# the kernel. Otherwise it returns 1.
check_removable() {
    [[ "$(lsblk -drno RM "$1")" == "1" ]]
}

info_fslabel() {
    lsblk -drno LABEL "$1" 2>/dev/null
}
info_fstype() {
    lsblk -drno FSTYPE "$1" 2>/dev/null
}
info_mountpath() {
    findmnt -no TARGET "$1" 2>/dev/null
}
info_partlabel() {
    lsblk -drno PARTLABEL "$1" 2>/dev/null
}
info_size() {
    lsblk -drno SIZE "$1" 2>/dev/null
}
info_type() {
    lsblk -drno TYPE "$1" 2>/dev/null
}
info_uuid() {
    lsblk -drno UUID "$1" 2>/dev/null
}
info_used() {
    lsblk -drno FSUSE% "$1" 2>/dev/null
}

get_luks_child() {
    local uuid="$(info_uuid "$1")"
    printf '%s' "/dev/mapper/luks-$uuid"
}
# }}}

# {{{ ··· DEVICE MANIPULATION
__mount() {
    msg "Mounting $1 ..."
    if (( udisks )); then
        udisksctl mount $mount_options --block-device "$1"
    else
        read -r -e -p "Choose the mountpoint directory: " dir
        [[ -z "$dir" ]] && return 1
        if [[ ! -e "$dir" ]]; then
            if ! mkdir -p "$dir"; then
                error "'$dir': Could not create directory."
                return 1
            fi
        fi
        sudo mount $mount_options "$1" "$dir"
    fi
}

__unmount() {
    msg "Unmounting $1 ..."
    if (( udisks )); then
        udisksctl unmount --block-device "$1"
    else
        sudo umount "$1"
    fi
}

action_eject() {
    check_device "$1" || return 1

    if [[ "$(info_fstype "$1")" == "crypto_LUKS" ]]; then
        action_unmount "$1" || return 1
    else
        check_mounted "$1" && action_unmount "$1"
    fi

    local -i retval=0
    if ! check_mounted "$1"; then
        msg "Ejecting $1 ..."
        device_type=$(info_type "$1")
        if (( udisks )) && [[ "$device_type" != "rom" ]]; then
            udisksctl power-off -b "$1"
            retval=$?
        else
            sudo eject "$1"
            retval=$?
        fi
        if (( retval == 0 )); then
            # Give the device some time to eject.
            sleep 1.5s
        else
            enter_to_continue
        fi
    fi
}

action_info() {
    check_device "$1" || return 1
    if (( udisks )); then
        udisksctl info -b "$devname" | less
    else
        lsblk -po NAME,FSTYPE,SIZE,FSUSE%,MOUNTPOINT "$1" | less
    fi
}

action_mount() {
    check_device "$1" || return 1
    if check_mounted "$1"; then
        error "$1 is already mounted."
        return 1
    fi

    if [[ "$(info_fstype "$1")" == "crypto_LUKS" ]]; then
        luks_child="$(get_luks_child "$1")"
        if [[ ! -b "$luks_child" ]]; then
            action_unlock "$1" || return 1
        fi
        action_mount "$luks_child"
        return $?
    fi

    if __mount "$1"; then
        msg "$1 mounted successfully."
        (( run_post_mount )) && post_mount "$1"
        sleep 0.1s
        return 0
    fi
    error "$1 could not be mounted."
    return 1
}

action_open() {
    check_device "$1" || return 1
    if [[ "$(info_fstype "$1")" == "crypto_LUKS" ]]; then
        luks_child="$(get_luks_child "$1")"
        if [[ ! -b "$luks_child" ]]; then
            action_mount "$1" || return 1
        fi
        action_open "$luks_child"
        return $?
    elif ! check_mounted "$1"; then
        action_mount "$1" || return 1
    fi
    msg "Opening $1 ..."
    filemanager "$(info_mountpath "$1")" || enter_to_continue
}

action_unmount() {
    check_device "$1" || return 1

    if [[ "$(info_fstype "$1")" == "crypto_LUKS" ]]; then
        luks_child="$(get_luks_child "$1")"
        if [[ -b "$luks_child" ]]; then
            if check_mounted "$luks_child"; then
                action_unmount "$luks_child" || return 1
            fi
            action_lock "$1" || return 1
        fi
        return $?
    fi

    if ! check_mounted "$1"; then
        error "$1 is already unmounted."
        return 1
    fi

    if __unmount "$1"; then
        msg "$1 unmounted successfully."
        (( run_post_unmount )) && post_unmount "$1"
        sleep 0.1s
        return 0
    fi
    error "$1 could not be unmounted."
    return 1
}

action_unlock() {
    msg "Opening luks volume ..."
    local -i retval=0
    if (( udisks )); then
        udisksctl unlock --block-device "$devname"
        retval=$?
    else
        sudo cryptsetup open --type luks -v "$devname" "luks-${devname##*/}"
        retval=$?
    fi
    (( retval != 0 )) && enter_to_continue
    return $retval
}

action_lock() {
    msg "Closing luks volume ..."
    local -i retval=0
    if (( udisks )); then
        udisksctl lock --block-device "$devname"
        retval=$?
    else
        sudo cryptsetup close --type luks "$devname"
        retval=$?
    fi
    (( retval != 0 )) && enter_to_continue
    return $retval
}
# }}}

# {{{ ··· MENU FUNCTIONS
list_devices() {
    all=()          # all devices
    listed=()       # all devices that are shown (ie, not hidden)
    mounted=()      # all devices that are shown and mounted
    device_number=0

    local -a removable=()
    local -a internal=()
    local -a optical=()

    while IFS='' read -r device; do
        all+=( "$device" )
    done < <(lsblk -plno NAME)

    for devname in "${all[@]}"; do
        # Hide excluded devices.
        for string in "${exclude[@]}"; do
            lsblk -dPno NAME,TYPE,FSTYPE,LABEL,MOUNTPOINT,PARTLABEL,UUID "$devname" \
                | grep -E "$string" >/dev/null 2>&1
            (( $? )) || continue 2
        done

        # Sort devices into arrays removable, internal, and optical.
        local device_type=$(info_type "$devname")
        if [[ "$device_type" == "part" ]]; then
            if check_removable "$devname"; then
                removable[${#removable[*]}]="$devname"
            else
                internal[${#internal[*]}]="$devname"
            fi
        elif [[ "$device_type" == "crypt" ]]; then
            # luks-xxxxx devices are never marked as removable, so we judge
            # whether they are removable by their parent crypto_LUKS device.
            local -i parent_found=0
            for parent_devname in "${all[@]}"; do
                local parent_uuid="$(info_uuid "$parent_devname")"
                [[ -z "$parent_uuid" ]] && continue
                if [[ "/dev/mapper/luks-$parent_uuid" == "$devname" ]]; then
                    if check_removable "$parent_devname"; then
                        removable[${#removable[*]}]="$devname"
                        parent_found=1
                        break
                    else
                        internal[${#internal[*]}]="$devname"
                        parent_found=1
                        break
                    fi
                fi
            done
            (( !parent_found )) && internal[${#internal[*]}]="$devname"
        # Normally we don't want to see a "disk", but if it has no partitions
        # (eg, internal storage on some portable media devices) then it should
        # be visible.
        elif [[ "$device_type" == "disk" ]]; then
            for (( i=0; i<${#all[@]}; i++ )); do
                [[ "${all[$i]}" =~ "$devname".+ ]] && continue 2
            done
            if check_removable "$devname"; then
                removable[${#removable[*]}]="$devname"
            else
                internal[${#internal[*]}]="$devname"
            fi
        elif [[ "$device_type" == "rom" ]]; then
            optical[${#optical[*]}]="$devname"
        else
            continue
        fi
    done

    clear
    # List internal media.
    if (( show_internal )) && (( ${#internal[*]} )); then
        print_separator_internal
        for devname in "${internal[@]}"; do
            print_device
        done
        printf '\n'
    fi
    # List removable media.
    if (( show_removable )) && (( ${#removable[*]} )); then
        print_separator_removable
        for devname in "${removable[@]}"; do
            print_device
        done
        printf '\n'
    fi
    # List optical media.
    if (( show_optical )) && (( ${#optical[*]} )); then
        print_separator_optical
        for devname in "${optical[@]}"; do
            print_device optical
        done
        printf '\n'
    fi
    (( !device_number )) && printf '%s\n' "No devices."
}

submenu() {
    # Make sure device is still valid.
    check_device "$devname" || return 1

    # Try to use a useful label to identify the device.
    local label="$(info_fslabel "$devname")"
    [[ -z "$label" ]] && label="$(info_partlabel "$devname")"
    [[ -z "$label" ]] && label="-"

    local fstype="$(info_fstype "$devname")"
    local size="$(info_size "$devname")"
    local used="$(info_used "$devname")"
    local uuid="$(info_uuid "$devname")"

    local -i mounted=0
    check_mounted "$devname" && mounted=1

    # Display the user interface.
    clear
    print_separator_device
    printf '%s\n' " device    : $devname"
    printf '%s\n' " label     : $label"
    if [[ "$fstype" == "crypto_LUKS" ]]; then
        printf '%s' " status    : "
        local -i unlocked=0
        if [[ -n "$uuid" ]]; then
            for dev in "${all[@]}"; do
                if [[ "$dev" == "/dev/mapper/luks-$uuid" ]]; then
                    printf '%s\n' "${GREEN}decrypted [luks-${uuid:0:4}...]${ALL_OFF}"
                    unlocked=1
                    break
                fi
            done
        fi
        (( !unlocked )) && printf '%s\n' "encrypted"
    else
        printf '%s' " mounted   : "
        if (( mounted )); then
            printf '%s\n' "${GREEN}yes${ALL_OFF}"
            printf '%s\n' " mountpath : $(info_mountpath "$devname")"
        else
            printf '%s\n' "${RED}no${ALL_OFF}"
        fi
    fi
    printf '%s\n' " fstype    : $fstype"
    printf '%s\n' " uuid      : $uuid"
    printf '%s\n' " size      : $size"
    (( mounted )) && printf '%s\n' " used      : $used"
    if (( show_commands == 1 )); then
        printf '\n'
        print_submenu_commands
    fi
    printf '\n'
    print_separator

    # Receive user input.
    local -i retval
    if ! read -r -e -p "${BOLD}Command:${ALL_OFF} " action; then
        # Exit on ctrl-d.
        printf '\n'
        exit 0
    fi
    case "$action" in
        "e") action_eject "$devname" || true;;
        "i") action_info "$devname" || true;;
        "m") action_mount "$devname" || true;;
        "o") action_open "$devname" || true;;
        "u") action_unmount "$devname" || true;;
        "b") return 1;;
        ""|"r") return 0;;
        "q") exit;;
        "?") print_help_submenu; return 0;;
        "1") sudo sh -c "cryptsetup luksDump '$devname' | less"; return 0;;
        "2") action_unlock "$devname"; return 1;;
        "3") action_lock "$devname"; return 1;;
        "4")
            if (( custom4_show )); then
                msg "Running custom command: $custom4_desc ..."
                custom4_command "$devname"
                enter_to_continue
            else
                invalid_command
            fi
            return 0;;
        "5")
            if (( custom5_show )); then
                msg "Running custom command: $custom5_desc ..."
                custom5_command "$devname"
                enter_to_continue
            else
                invalid_command
            fi
            return 0;;
        "6")
            if (( custom6_show )); then
                msg "Running custom command: $custom6_desc ..."
                custom6_command "$devname"
                enter_to_continue
            else
                invalid_command
            fi
            return 0;;
         *) invalid_command; return 0;;
    esac
}

select_action() {
    local devname
    local letter
    print_separator
    if ! read -r -e -p "${BOLD}Command:${ALL_OFF} " action; then
        # Exit on ctrl-d.
        printf '\n'
        exit 0
    fi
    if [[ "$action" =~ ^[1-9] ]]; then
        if [[ "$action" =~ ^[1-9][0-9]*$ ]]; then
            # Zero-based numbering for array elements, so subtract one.
            local number="$(( action - 1 ))"
            if (( number >= device_number )); then
                invalid_command
                return 1
            fi
            devname=${listed[number]}
            while true; do
                submenu || break
            done
        elif [[ "$action" =~ ^[1-9][0-9]*[eimou]$ ]]; then
            # Zero-based numbering for array elements, so subtract one.
            local number="$(( ${action%?} - 1 ))"

            if (( number >= device_number )); then
                invalid_command
                return 1
            fi
            devname="${listed[number]}"

            letter="${action: -1}"
            case "$letter" in
                "e") action_eject "$devname";;
                "i") action_info "$devname";;
                "m") action_mount "$devname";;
                "o") action_open "$devname";;
                "u") action_unmount "$devname";;
                 *)  return 1;;
            esac
            return 0
        else
            invalid_command
            return 1
        fi
    else
        case "$action" in
            "a")
                if (( ! ${#mounted[*]} )); then
                    error "No devices mounted."
                    return 1
                fi
                printf '\n'
                read -r -e -p "Unmount all devices [y/N]?: " unmount
                [[ "$unmount" != "y" ]] && [[ "$unmount" != "Y" ]] && return 0
                clear
                for devname in "${mounted[@]}"; do
                    action_unmount "$devname" || continue
                done
                enter_to_continue
                return 1;;
            "r"|"") return 0;;
            "q"|"b") exit 0;;
            "?") print_help; return 0;;
            *) invalid_command; return 1;;
        esac
    fi
}
# }}}

declare -i device_number=0
declare -a all=()
declare -a listed=()
declare -a mounted=()

while true; do
    list_devices
    (( show_commands )) && print_commands
    select_action
done
