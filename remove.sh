#!/bin/bash

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

if [ -e "$UNITFILE" ]; then
    sudo systemctl disable usb-gadget
    sudo rm "$UNITFILE"    
    sudo systemctl daemon-reload
fi

if [ -e /etc/usb-gadgets ]; then
    sudo rm -Rf /etc/usb-gadgets
fi

if [ -e "$USBFILE" ]; then
    sudo rm "$USBFILE"
fi

if [ -e /etc/dnsmasq.d/usb-gadget ]; then
    rm /etc/dnsmasq.d/usb-gadget
    sudo apt purge dnsmasq
fi

if [ -e /etc/network/interfaces.d/usb0 ]; then
    ifdown usb0
    rm /etc/network/interfaces.d/usb0
fi

if $(grep -q modules-load=dwc2 /boot/cmdline.txt) ; then
    echo
    echo "remove line modules-load=dwc2 from /boot/cmdline.txt"
    if ! confirm ; then
        exit
    fi
    cat /boot/cmdline.txt
    sudo sed -i '${s/ modules-load=dwc2//}' /boot/cmdline.txt
    cat /boot/cmdline.txt
fi

if $(grep -q 'denyinterfaces usb0' /etc/dhcpcd.conf) ; then
    echo
    echo "remove line 'denyinterfaces usb0' from /etc/dhcpcd.conf"
    if ! confirm ; then
        exit
    fi
    sudo sed -i '${s/denyinterfaces usb0//}' /etc/dhcpcd.conf
fi

# TODO: libcomposite from /etc/modules
