#!/bin/bash -x 

# Check if image matches os type

image_type="$(lbdisttool.py -l | cut -d'.' -f1 )"
host_type="$(lbdisttool.py -l --os-release /etc/host-release | cut -d'.' -f1 )"

[[ "$host_type" != "$image_type" ]] && echo "Image type does not match OS type, skip !" && exit 0

# If no shipped module is found, then compile from source
if LB_HOW=shipped_modules bash -x /entry.sh; then
   echo "Successfully loaded shipped module"
elif LB_HOW=compile bash -x /entry.sh; then
   echo "Successfully loaded compiled module"
fi

# Drop modules to the host so it can independently load from OS
KODIR="/lib/modules/$(uname -r)/extra/drbd"
if [[ $LB_DROP == yes ]]; then
   # drop modules
   mkdir -vp $(basename "$KODIR") 
   cp -vfr /tmp/ko "${KODIR}"
   # register modules
   depmod -a
   # onboot load modules 
   cp -vf /pkgs/drbd.modules-load /etc/modules-load.d/hwameistor.drbd.conf
   # drop drbd utils
   cp -vf /pkgs/drbd-utils/* /usr/local/bin/
fi
