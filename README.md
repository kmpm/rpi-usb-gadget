# rpi-usb-gadget
Script for setting up a Raspberry PI 4 as USB gadget.

I can not take full credit for this since I am standing
on the shoulders of giants.
- https://gist.github.com/ianfinch/08288379b3575f360b64dee62a9f453f
- https://pastebin.com/VtAusEmf
- https://www.hardill.me.uk/wordpress/2019/11/02/pi4-usb-c-gadget/
- https://github.com/hardillb/rpi-gadget-image-creator/blob/master/usr/local/sbin/usb-gadget.sh-orig


## Usage
```shell
wget https://raw.githubusercontent.com/kmpm/rpi-usb-gadget/master/rpi4-usb.sh
bash rpi4-usb.sh
```
If you answer no to any of the questions the script will exit
but should be safe to restart.
You will be asked to choose between ECM or RNDIS type of network.
RNDIS works better if your host is Windows and ECM might be better on Linux/Mac.

If the script doesn't run successfully you might have a broken
partial configuration.


## Warning / License
This script will modify '/boot/config.txt', '/boot/cmdline.txt' and other files.
Warning, It might brick your device!

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
