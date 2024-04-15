#!/bin/bash
# Set up a Raspberry Pi 4 as a USB-C Ethernet Gadget
# Based on:
#     - https://www.hardill.me.uk/wordpress/2019/11/02/pi4-usb-c-gadget/
#     - https://pastebin.com/VtAusEmf
#     - https://gist.github.com/ianfinch/08288379b3575f360b64dee62a9f453f

# Options for later
BASE_IP=10.55.0
NETMASK=255.255.255.248
HOSTPREFIX="02"     # hex, two digits only
DEVICEPREFIX="06"   # hex, two digits only

# variables that will be used
DO_MODIFY=true
USE_DNSMASQ=false
CONFIG_FILE=/boot/firmware/config.txt
CMDLINE_FILE=/boot/firmware/cmdline.txt
USBFILE=/usr/local/sbin/usb-gadget.sh
UNITFILE=/lib/systemd/system/usb-gadget.service





# some usefull functions
confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

teeconfirm() {
    line=$1
    f=$2
    if ! $(grep -q "$line" $f); then
        echo
        echo "Add the line '$line' to '$f'"
        ! confirm && exit
        if $DO_MODIFY ; then
            echo "$line" | sudo tee -a $f
        fi
    fi
}

validate_ip_format() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid IP address format"
        return 1
    fi
    return 0
}   

ask_for_ip() {
    echo
    echo "Enter the base IP address for the USB network"
    echo "Only the first 3 groups"
    echo "Example $BASE_IP"
    read -p "Enter the base IP address: " ip
    if ! validate_ip_format "$ip.1"; then
        ask_for_ip
    elif [[ ! -z $ip ]]; then
        BASE_IP=$ip
    fi

}



##### Actual work #####

## check if -n flag is set
if [[ $1 == "-n" ]]; then
    DO_MODIFY=false
fi

# check if $CONFIG_FILE exists or go back to old path
if [[ ! -e $CONFIG_FILE ]]; then
    CONFIG_FILE=/boot/config.txt
    CMDLINE_FILE=/boot/cmdline.txt
fi


SERIAL=`cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2` # Pi's serial number

## calculate MAC addresses
padded='00000000000000'$SERIAL
for i in -10 -8 -6 -4 -2; do
    basemac=$basemac':'${padded: $i:2}
done
hostmac=$HOSTPREFIX$basemac
devmac=$DEVICEPREFIX$basemac




## warning

cat << EOF
This script will modify '$CONFIG_FILE', '$CMDLINE_FILE' and other files.
Warning, It might brick your device!

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Continue with modifications?
EOF
! confirm && exit


# check if user wants dhcp server using dnsmasq
echo "Do you want to use a DHCP server for the USB network?"
echo "This will install dnsmasq and configure it for the USB network"
if confirm ; then
    USE_DNSMASQ=true
    ask_for_ip
else
    echo
    echo "You can configure the IP address later in /etc/network/interfaces.d/usb0"
    echo "and the DHCP server in /etc/dnsmasq.d/usb-gadget"
fi


# enable dwc2 overlay

teeconfirm "dtoverlay=dwc2" $CONFIG_FILE
if ! $(grep -q modules-load=dwc2 $CMDLINE_FILE) ; then
    echo
    echo "Add the line modules-load=dwc2 to $CMDLINE_FILE"
    if ! confirm ; then
        exit
    fi
    if $DO_MODIFY ; then
    sudo sed -i '${s/$/ modules-load=dwc2/}' $CMDLINE_FILE
    fi
fi


# enable libcomposite module
teeconfirm "libcomposite" "/etc/modules"


# configurde dnsmasq if wanted
if $USE_DNSMASQ ; then
    
    teeconfirm "denyinterfaces usb0" "/etc/dhcpcd.conf"

    # install dnsmasq
    if [[ ! -e /etc/dnsmasq.d ]] ; then
        echo
        echo "Install dnsmasq"
        ! confirm && exit
        sudo apt install dnsmasq
    fi

    # configure dnsmasq for usb0
    if [[ ! -e /etc/dnsmasq.d/usb-gadget ]] ; then
        cat << EOF | sudo tee /etc/dnsmasq.d/usb-gadget > /dev/null
dhcp-rapid-commit
dhcp-authoritative
no-ping
interface=usb0
dhcp-range=usb0,$BASE_IP.2,$BASE_IP.6,$NETMASK,1h
domain=usb.lan
dhcp-option=usb0,3
leasefile-ro
EOF
        echo "Created /etc/dnsmasq.d/usb-gadget"
    fi

    echo "configure static ip '$BASE_IP.1' for interface usb0"
    if [[ ! -e /etc/network/interfaces.d/usb0 ]] ; then
        cat << EOF | sudo tee /etc/network/interfaces.d/usb0 > /dev/null
auto usb0
allow-hotplug usb0
  address $BASE_IP.1
  netmask $NETMASK
EOF
        echo "Created /etc/network/interfaces.d/usb0"
    fi

else
    echo "Setting usb0 to get address from dhcp"
    if [[ ! -e /etc/network/interfaces.d/usb0 ]] ; then
        cat << EOF | sudo tee /etc/network/interfaces.d/usb0 > /dev/null
auto usb0
allow-hotplug usb0
iface usb0 inet dhcp
EOF
    fi
        echo "Created /etc/network/interfaces.d/usb0"
fi

if [[ ! -e /etc/usb-gadgets ]]; then 
    sudo mkdir -p /etc/usb-gadgets
fi
if [[ ! -e /etc/usb-gadgets/net-rndis ]]; then
    cat << EOF | sudo tee /etc/usb-gadgets/net-rndis > /dev/null
config1="RNDIS"
config2="CDC"
usb_version="0x0200" # USB 2.0
device_class="0xEF"
device_subclass="0x02"
bcd_device="0x0100" # v1.0.0
device_protocol="0x01"
vendor_id="0x1d50"
product_id="0x60c7"
manufacturer="Ian"
product="RPi4 USB Gadget"
serial="$SERIAL"
attr="0x80" # Bus powered
power="250"
ms_vendor_code="0xcd" # Microsoft
ms_qw_sign="MSFT100" # also Microsoft (if you couldn't tell)
ms_compat_id="RNDIS" # matches Windows RNDIS Drivers
ms_subcompat_id="5162001" # matches Windows RNDIS 6.0 Driver
dev_mac="$devmac"
host_mac="$hostmac"
use_dnsmasq=$USE_DNSMASQ
EOF
fi

if [[ ! -e /etc/usb-gadgets/net-ecm ]]; then
    cat << EOF | sudo tee /etc/usb-gadgets/net-ecm > /dev/null
config1="ECM"
usb_version="0x0200" # USB 2.0
vendor_id="0x1d6b" # Linux Foundation
product_id="0x0104" # Multifunction composite gadget
bcd_device="0x0100" # v1.0.0
device_class="0xEF"
device_subclass="0x02"
device_protocol="0x01"
manufacturer="github.com/kmpm"
product="RPi4 USB Gadget"
serial="$SERIAL"
power="250"
host_mac="$hostmac"
dev_mac="$devmac"
use_dnsmasq=$USE_DNSMASQ
EOF

fi


# create script, $USBFILE, for usb gadget device in 
if sudo test ! -e "$USBFILE" ; then
    cat << 'EOF' | sudo tee $USBFILE > /dev/null
#!/bin/bash

gadget=/sys/kernel/config/usb_gadget/pi4

if [[ ! -e "/etc/usb-gadgets/$1" ]]; then
    echo "No such config, $1, found in /etc/usb-gadgets"
    exit 1
fi
source /etc/usb-gadgets/$1



mkdir -p ${gadget}
echo "${vendor_id}" > ${gadget}/idVendor
echo "${product_id}" > ${gadget}/idProduct
echo "${bcd_device}" > ${gadget}/bcdDevice
echo "${usb_version}" > ${gadget}/bcdUSB


if [ ! -z "${device_class}" ] ; then
    echo "${device_class}" > ${gadget}/bDeviceClass
    echo "${device_subclass}" > ${gadget}/bDeviceSubClass
    echo "${device_protocol}" > ${gadget}/bDeviceProtocol
fi

mkdir -p ${gadget}/strings/0x409
echo "${manufacturer}" > ${gadget}/strings/0x409/manufacturer
echo "${product}" > ${gadget}/strings/0x409/product
echo "${serial}" > ${gadget}/strings/0x409/serialnumber


mkdir ${gadget}/configs/c.1
echo "${power}" > ${gadget}/configs/c.1/MaxPower
if [ ! -z "${attr}" ]; then
    echo "${attr}" > ${gadget}/configs/c.1/bmAttributes
fi

mkdir -p ${gadget}/configs/c.1/strings/0x409
echo "${config1}" > ${gadget}/configs/c.1/strings/0x409/configuration

if [ "${config1}" = "ECM" ] ; then
    mkdir -p ${gadget}/functions/ecm.usb0
    echo "${dev_mac}" > ${gadget}/functions/ecm.usb0/dev_addr
    echo "${host_mac}" > ${gadget}/functions/ecm.usb0/host_addr

    ln -s ${gadget}/functions/ecm.usb0 ${gadget}/configs/c.1/
    
    #mkdir -p ${gadget}/functions/acm.usb0
    #ln -s functions/acm.usb0 ${gadget}/configs/c.1/
fi

if [ "${config1}" = "RNDIS" ] ; then
    mkdir -p ${gadget}/os_desc
    echo "1" > ${gadget}/os_desc/use
    echo "${ms_vendor_code}" > ${gadget}/os_desc/b_vendor_code
    echo "${ms_qw_sign}" > ${gadget}/os_desc/qw_sign

    mkdir -p ${gadget}/functions/rndis.usb0
    echo "${dev_mac}" > ${gadget}/functions/rndis.usb0/dev_addr
    echo "${host_mac}" > ${gadget}/functions/rndis.usb0/host_addr
    echo "${ms_compat_id}" > ${gadget}/functions/rndis.usb0/os_desc/interface.rndis/compatible_id
    echo "${ms_subcompat_id}" > ${gadget}/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

    ln -s ${gadget}/configs/c.1 ${gadget}/os_desc
    ln -s ${gadget}/functions/rndis.usb0 ${gadget}/configs/c.1
fi

ls /sys/class/udc > ${gadget}/UDC

udevadm settle -t 5 || :
ifup usb0
if $use_dnsmasq ; then
    service dnsmasq restart
fi
EOF

    sudo chmod 750 $USBFILE
    echo "Created $USBFILE"
fi


prompt="Pick an option:"
options=("RNDIS Network device type (best with windows)" "ECM Network device type")

DEVICETYPE="net-rndis"

echo -e "\n\nSelect network device type"
PS3="$prompt "
select opt in "${options[@]}" ; do 
    case "$REPLY" in
    1) DEVICETYPE="net-rndis";break;;
    2) DEVICETYPE="net-ecm";break;;
    *) echo "Invalid option. Try another one.";continue;;
    esac
done
echo -e "\nYou selected '$DEVICETYPE' which will be configured in"
echo -e "the systemd unit file for usb-gadget.\n"


# make sure $USBFILE runs on every boot using $UNITFILE
if [[ ! -e $UNITFILE ]] ; then
    cat << EOF | sudo tee $UNITFILE > /dev/null
[Unit]
Description=USB gadget initialization
After=network-online.target
Wants=network-online.target
#After=systemd-modules-load.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$USBFILE $DEVICETYPE

[Install]
WantedBy=sysinit.target

EOF
    echo "Created $UNITFILE"
    sudo systemctl daemon-reload
    if $DO_MODIFY ; then
        sudo systemctl enable usb-gadget
    else
        sudo sytemctl disable usb-gadget
    fi
fi

cat << EOF


Done setting up as USB gadget
You must reboot for changes to take effect

If you chose to use dnsmasq, then
you can reach the device on $BASE_IP.1 when connected by USB.
If not then your host must assign an IP address to the usb0 interface.


If you want to disable the usb0/gadget interface then
please run 'sudo systemctl disable usb-gadget'
and reboot.

EOF

