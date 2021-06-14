# rpi-usb-gadget
Script for setting up a Raspberry PI 4 as USB gadget.

I can not take full credit for this since I am standing
on the shoulders of giants.
- https://gist.github.com/ianfinch/08288379b3575f360b64dee62a9f453f
- https://pastebin.com/VtAusEmf
- https://www.hardill.me.uk/wordpress/2019/11/02/pi4-usb-c-gadget/
- https://github.com/hardillb/rpi-gadget-image-creator/blob/master/usr/local/sbin/usb-gadget.sh-orig


# Usage
```shell
wget https://raw.githubusercontent.com/kmpm/rpi-usb-gadget/master/rpi4-usb.sh
bash rpi4-usb.sh
```
If you answer no to any of the questions the script will exit
but should be safe to restart.
If the script doesn't run successfully you might have a broken
partial configuration.