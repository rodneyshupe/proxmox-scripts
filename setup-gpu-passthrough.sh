#!/usr/bin/env bash

# See https://pve.proxmox.com/wiki/Pci_passthrough for more details.

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

function append_line() {
    local line="$1"
    local file="$2"

    grep "^${line}$" "$file" -q || echo "$line" | tee -a $file
}

# Function to check dependancies
checkfor () {
    command -v $1 >/dev/null 2>&1 || { 
        echo >&2 "ERROR: $1 required. Please install and try again."; 
        exit 1; 
    }
}

if ! confirm "Install support for GPU passthrough" "N"; then
    exit 0
fi

echo "Step 1: Configuring boot options"
# You can SSH directly into your Proxmox server, or utilize the noVNC Shell terminal under 'Node' and open up the /etc/default/grub file using nano or any preferable text editor.
cpu_vendor_id="$(cat /proc/cpuinfo | grep '^vendor_id[[:space:]]*:' | head -1 | awk '{print $3}')"
if [[ "$cpu_vendor_id" == "GenuineIntel" ]]; then
    echo "  Using Intel CPU ($cpu_vendor_id)"
    boot_option="intel_iommu"
else
    echo "  Using AMD CPU ($cpu_vendor_id)"
    boot_option="amd_iommu"
fi

if [ -f /etc/kernel/cmdline ]; then
    if grep -e '${boot_option}=' /etc/kernel/cmdline -q; then
        echo "  Kernel boot option already exists"
    else
        echo "  Updating kernel boot options"
        if [[ "$cpu_vendor_id" == "GenuineIntel" ]]; then
            sed -i -e 's/^\([[:space:]]root=.*$\)/\1 intel_iommu=on' /etc/kernel/cmdline
        else
            sed -i -e 's/^\([[:space:]]root=.*$\)/\1 amd_iommu=on' /etc/kernel/cmdline
        fi
        /usr/sbin/proxmox-boot-tool refresh
    fi
fi
if [ -f /etc/default/grub ]; then
    if grep -e '^GRUB_CMDLINE_LINUX_DEFAULT="[^"]*${boot_option}=' /etc/default/grub -q; then
        echo "  Grub boot option already exists"
    else
        echo "  Updating Grub boot options"
        if [[ "$cpu_vendor_id" == "GenuineIntel" ]]; then
            sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 intel_iommu=on"/' /etc/default/grub
        else
            sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_iommu=on"/' /etc/default/grub
        fi

        exec /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg
    fi
fi
#TODO: Add optional item: iommu=pt

echo "Step 2: Add VFIO Modules"
# Add a few VFIO modules to your Proxmox system
append_line 'vfio' /etc/modules
append_line 'vfio_iommu_type1' /etc/modules
append_line 'vfio_pci' /etc/modules
append_line 'vfio_virqfd' /etc/modules

echo "Step 3: IOMMU interrupt remapping"
append_line "options vfio_iommu_type1 allow_unsafe_interrupts=1" /etc/modprobe.d/iommu_unsafe_interrupts.conf
append_line "options kvm ignore_msrs=1" /etc/modprobe.d/kvm.conf


echo "Step 4: Blacklisting Drivers"
# Blacklist the drivers so that the Proxmox host system does not utilize our GPU(s)
append_line "blacklist radeon" /etc/modprobe.d/blacklist.conf
append_line "blacklist nouveau" /etc/modprobe.d/blacklist.conf
append_line "blacklist nvidia" /etc/modprobe.d/blacklist.conf


echo "Step 5: Adding GPU to VFIO"
gpu_id="$(lspci -v | grep '^[0-9].*Graphics' | grep --only-matching '^[^ ]*' | head -1)"
audio_id="$(lspci -v | grep '^[0-9].*Audio' | grep --only-matching '^[^ ]*' | head -1)"

gpu_vendor_id="$(lspci -n -s $gpu_id | awk '{print $3}')"
audio_vendor_id="$(lspci -n -s $audio_id | awk '{print $3}')"

echo "  Using vendor_ids: GPU=$gpu_vendor_id Audio=$audio_vendor_id"
append_line "options vfio-pci ids=$gpu_vendor_id,$audio_vendor_id disable_vga=1" /etc/modprobe.d/vfio.conf

echo "  Update configs..."
/usr/sbin/update-initramfs -u

# Restart
if confirm "To complete a reset is required.  Reset?" "Y"; then
    reset
fi
