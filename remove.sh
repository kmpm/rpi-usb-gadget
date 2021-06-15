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

cat << EOF
This script will modify '/boot/config.txt', '/boot/cmdline.txt' and other files.
Warning, It might brick your device!
Do not run unless you understand what it is doing.

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
    sudo rm /etc/dnsmasq.d/usb-gadget
    sudo systemctl stop dnsmasq
    sudo apt purge dnsmasq
fi

if [ -e /etc/network/interfaces.d/usb0 ]; then
    sudo ifdown usb0
    sudo rm /etc/network/interfaces.d/usb0
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

if $(grep -q '^libcomposite' /etc/modules) ; then
    echo
    echo "remove line 'libcomposite' from /etc/modules"
    if ! confirm ; then
        exit
    fi
    sudo sed -i '${s/^libcomposite//}' /etc/modules
fi
