#!/usr/bin/env bash

#Check if script is being run as root
if [ "$(id -u)" != "0" ]; then
   echo "ERROR: This script must be run as root" 1>&2
   exit 1
fi

function confirm() {
    local prompt="$1"
    local default=${2:-Y}
    local exit_on_no=${3:-false}

    if [[ "$default" == "Y" ]]; then
        choice="Y/n"
    elif [[ "$default" == "N" ]]; then
        choice="y/N"
    else
        choice="y/n"
    fi
    echo -n "$prompt [$choice] " >&2
    read answer

    [[ "$answer" == "" ]] && answer="$default"
    
    case "$answer" in
        Y|y)
            return 0
            ;;
        N|n)
            if $exit_on_no; then
                echo "Exit!" >&2
                exit 1
            else
                return 1
            fi
            ;;
        *)
            echo "Invalid response." >&2
            return confirm "$prompt" "$default" "$exit_on_no"
            ;;
    esac
}

function get_password() {
    local password="x"
    local verify="y"
    while [[ "$password" != "$verify" ]]; do
        echo -n "  Enter password: "
        read -s password
        echo -n "  Re-enter password: "
        read -s verify

        [[ "$password" != "$verify" ]]; echo "  Password doesn't match. Retry."
    done

    echo "$password"
}

function remove_subscription_popup() {
    local file="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
    sudo cp "$file"{,.bak}
    local search_str="No valid subscription"
    local line_num=$(grep -n -B 1 "$search_str" "$file" | head -1 | cut -d'-' -f1)
    if [ -n "$line_num" ]; then
        local replacement_text="void({ // Ext.Msg.show({"
        if ! grep -B 1 "$search_str" "$file" | head -1 | grep "$replacement_text" -q; then
            sudo sed -i "${line_num},$((line_num+2))s/Ext\.Msg\.show({/$(echo "$replacement_text" | sed 's/\//\\\//g')/" "$file"
        fi
    fi
    sudo systemctl restart pveproxy.service
}

function setup_nonsubscription() {
    echo "Fix repositories for non-subscription"
    echo '# PVE pve-no-subscription repository provided by proxmox.com
# NOT recommended for production use
deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription
' | tee /etc/apt/sources.list.d/pve-no-subscription.list
    sed -i -e 's/^[[:space:]]*deb /# deb /' /etc/apt/sources.list.d/pve-enterprise.list
    apt update && apt dist-upgrade

    # Remove popup
    remove_subscription_popup
}

function add_admin_user() {
    local user="$1"
    local password="$2"
    local email="$3"
    local realm="${4:-pve}"

    if [ -z "$user" ] || [ -z "$password" ] || [ -z "$email" ]; then
        echo -n "ERROR: add_admin_user Missing parameter: "
        [ -z "$user" ] && echo -n "username "
        [ -z "$password" ] && echo -n "password "
        [ -z "$email" ] && echo -n "email"
        echo
    elif [[ "$realm" != "pve" ]] && [[ "$realm" != "pam" ]]; then
        echo "ERROR: supported realm: $realm"
    else
        echo "Add admin user $user@$realm"
        if [[ "$realm" == "pam" ]]; then
            apt install -y -q -q sudo >/dev/null
            getent group sudo > /dev/null
            if [ $? -ne 0 ] ; then
                sudo su -c "groupadd sudo"
            fi
            sudo su -c "useradd $user --shell /bin/bash --create-home --groups sudo"
            echo $user:$password | sudo chpasswd
        fi
        pveum user add $user@$realm -comment "Admin User"
        if [ $? -eq 0 ] && [[ "$realm" == "pve" ]]; then
            pvesh set /access/password --userid "$user" --password "$password"
        fi

        pveum user modify $user@$realm -email "$email"
        pveum user modify $user@$realm -group admin
    fi
}



pveum group add admin -comment "System Administrators"
pveum acl modify / -group admin -role Administrator

if confirm "Create a seperate Proxmox admin user?" "N"; then
    read -p "  Admin username: " username
    password="$(get_password)"
    read -p "  email address: " email
    add_admin_user "$username" "$password" "$email"
fi

if [ $(pveum user list --enabled --output-format yaml | grep 'userid: ' | wc -l) -gt 1 ] \
&& confirm "Do you want to disable the root user from logging in to the UI?" "N"; then
    echo "Disable Root UI Login"
    pveum user modify root@pam -enable 0
fi

if confirm "Do you have a Proxmox subscription?" "N"; then
    if confirm "Add non-subcription repositories and disable login message?" "Y"; then
        setup_nonsubscription
    fi
fi

if confirm "Setup GPU passthrough?" "N"; then
    apt install -y -q -q curl >/dev/null
    curl -sSL https://raw.githubusercontent.com/rodneyshupe/dark-browser/main/setup-gpu-passthrough.sh | bash
fi