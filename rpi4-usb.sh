#!/bin/bash
# Set up a Raspberry Pi 4 as a USB-C Ethernet Gadget
# Based on:
#     - https://www.hardill.me.uk/wordpress/2019/11/02/pi4-usb-c-gadget/
#     - https://pastebin.com/VtAusEmf
#     - https://gist.github.com/ianfinch/08288379b3575f360b64dee62a9f453f

# Options for later
USBFILE=/root/usb.sh
BASE_IP=10.55.0

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
        echo "$line" | sudo tee -a $f
    fi
}

##### Actual work #####

teeconfirm "dtoverlay=dwc2" "/boot/config.txt"

if ! $(grep -q modules-load=dwc2 /boot/cmdline.txt) ; then
    echo
    echo "Add the line modules-load=dwc2 to /boot/cmdline.txt"
    if ! confirm ; then
        exit
    fi
    sudo sed -i '${s/$/ modules-load=dwc2/}' /boot/cmdline.txt
fi

teeconfirm "libcomposite" "/etc/modules"

teeconfirm "denyinterfaces usb0" "/etc/dhcpcd.conf"

# install dnsmasq
if [[ ! -e /usr/sbin/dnsmasq ]] ; then
    echo
    echo "Install dnsmasq"
    ! confirm && exit
    sudo apt install dnsmasq
fi

# configure dnsmasq for usb0
if [[ ! -e /etc/dnsmasq.d/usb ]] ; then
	cat << EOF | sudo tee /etc/dnsmasq.d/usb > /dev/null
interface=usb0
dhcp-range=$BASE_IP.2,$BASE_IP.6,255.255.255.248,1h
dhcp-option=3
leasefile-ro
EOF
    echo "Created /etc/dnsmasq.d/usb"
fi

# configure static ip for interface usb0
if [[ ! -e /etc/network/interfaces.d/usb0 ]] ; then
    cat << EOF | sudo tee /etc/network/interfaces.d/usb0 > /dev/null
auto usb0
allow-hotplug usb0
iface usb0 inet static
  address $BASE_IP.1
  netmask 255.255.255.248
EOF
    echo "Created /etc/network/interfaces.d/usb0"
fi

# create script, $USBFILE, for usb gadget device in 
if sudo test ! -e "$USBFILE" ; then
    cat << 'EOF' | sudo tee $USBFILE > /dev/null
#!/bin/bash

gadget=/sys/kernel/config/usb_gadget/pi4

usb_version="0x0200" # USB 2.0
device_class="0xEF"
device_subclass="0x02"
bcd_device="0x0100" # v1.0.0
device_protocol="0x01"
vendor_id="0x1d50"
product_id="0x60c7"
#vendor_id="0x1d6b" # Linux Foundation
#product_id="0x0104" # Multifunction composite gadget
manufacturer="Ian"
product="RPi4 USB Gadget"
serial="fedcba9876543211"
attr="0x80" # Bus powered
power="250"
config1="RNDIS"
config2="CDC"
ms_vendor_code="0xcd" # Microsoft
ms_qw_sign="MSFT100" # also Microsoft (if you couldn't tell)
ms_compat_id="RNDIS" # matches Windows RNDIS Drivers
ms_subcompat_id="5162001" # matches Windows RNDIS 6.0 Driver
mac="01:23:45:67:89:ab"
dev_mac="02$(echo ${mac} | cut -b 3-)"
host_mac="12$(echo ${mac} | cut -b 3-)"

mkdir -p ${gadget}
echo "${usb_version}" > ${gadget}/bcdUSB
echo "${device_class}" > ${gadget}/bDeviceClass
echo "${device_subclass}" > ${gadget}/bDeviceSubClass
echo "${vendor_id}" > ${gadget}/idVendor
echo "${product_id}" > ${gadget}/idProduct
echo "${bcd_device}" > ${gadget}/bcdDevice
echo "${device_protocol}" > ${gadget}/bDeviceProtocol

mkdir -p ${gadget}/strings/0x409
echo "${manufacturer}" > ${gadget}/strings/0x409/manufacturer
echo "${product}" > ${gadget}/strings/0x409/product
echo "${serial}" > ${gadget}/strings/0x409/serialnumber

mkdir ${gadget}/configs/c.1
echo "${attr}" > ${gadget}/configs/c.1/bmAttributes
echo "${power}" > ${gadget}/configs/c.1/MaxPower
mkdir -p ${gadget}/configs/c.1/strings/0x409
echo "${config1}" > ${gadget}/configs/c.1/strings/0x409/configuration

mkdir -p ${gadget}/os_desc
echo "1" > ${gadget}/os_desc/use
echo "${ms_vendor_code}" > ${gadget}/os_desc/b_vendor_code
echo "${ms_qw_sign}" > ${gadget}/os_desc/qw_sign

mkdir -p ${gadget}/functions/rndis.usb0
echo "${dev_mac}" > ${gadget}/functions/rndis.usb0/dev_addr
echo "${host_mac}" > ${gadget}/functions/rndis.usb0/host_addr
echo "${ms_compat_id}" > ${gadget}/functions/rndis.usb0/os_desc/interface.rndis/compatible_id
echo "${ms_subcompat_id}" > ${gadget}/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

#mkdir ${gadget}/configs/c.2
#echo "${attr}" > ${gadget}/configs/c.2/bmAttributes
#echo "${power}" > ${gadget}/configs/c.2/MaxPower
#mkdir -p ${gadget}/configs/c.2/strings/0x409
#echo "${config2}" > ${gadget}/configs/c.2/strings/0x409/configuration

#mkdir -p ${gadget}/functions/ecm.usb0
#echo "${dev_mac}" > ${gadget}/functions/ecm.usb0/dev_addr
#echo "${host_mac}" > ${gadget}/functions/ecm.usb0/host_addr

ln -s ${gadget}/configs/c.1 ${gadget}/os_desc
ln -s ${gadget}/functions/rndis.usb0 ${gadget}/configs/c.1
#ln -s ${gadget}/functions/ecm.usb0 ${gadget}/configs/c.2

ls /sys/class/udc > ${gadget}/UDC

udevadm settle -t 5 || :
ifup usb0
service dnsmasq restart
EOF

    sudo chmod 750 $USBFILE
    echo "Created $USBFILE"
fi

# make sure $USBFILE runs on every boot
if ! $(grep -q $USBFILE /etc/rc.local) ; then
    echo
    echo "Add line '$USBFILE' to /etc/rc.local'?"
    ! confirm && exit
    sudo sed -i "/^exit 0/i $USBFILE" /etc/rc.local    
fi


echo "Done setting up as USB gadget"
echo "You must reboot for changes to take effect"
echo "You can reach the device on $BASE_IP.1 when connected by USB"
