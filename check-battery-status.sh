#!/bin/bash
# check battery & AC status (Linux)
#
# * By Kordian Witek <code [at] kordy.com>
#

# check that we have the right utils
which acpi >&/dev/null || { echo "$0: no \`ACPI' utility installed!" >&2; exit 1; }
which upower >&/dev/null || { echo "$0: no \`upower' utility installed!" >&2; exit 1; }

echo "* Battery (`date "+%H:%M"`):"
acpi -bi
upower -i $(upower -e | grep BAT) | egrep 'vendor|state|time to empty|energy-rate|energy-full|energy:|percentage|capacity|technology'

echo -e "\n* AC Power (`date "+%H:%M"`):"
acpi -ai
upower -i $(upower -e | grep AC) |egrep 'updated|online'

echo -e "\n* Misc (`date "+%H:%M"`):"
acpi -t

echo -en "\n* Available CPU Freq Power Schemes:\t\t"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 
echo -en "* Currently enabled CPU Freq Power Scheme:\t"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

echo -e "\nNOTE: To change your processor to performance mode use:
$ echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
performance"

# EOF
