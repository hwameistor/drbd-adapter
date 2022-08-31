#!/bin/bash -x 

# Check if image matches os type

which lbdisttool.py

image_type="$(lbdisttool.py -l | awk -F'.' '{print $1}' )"
host_type="$(lbdisttool.py -l --os-release /etc/host-release | awk -F'.' '{print $1}' )"

# For Kylin v10, use RHEL 8 base for now
if [ -z $host_type ] \
   && uname -r | grep -i '.ky10.' \
   && grep -iw kylin /etc/host-release; then
   echo "Host distro is Kylin V10"
   host_type=rhel8
fi

if [[ $host_type != $image_type ]]; then 
   echo "Image type does not match OS type, skip !" 
   exit 0
fi

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
   cp -vf /pkgs/drbd.modules-load.conf /etc/modules-load.d/drbd.conf
   # drop drbd utils
   cp -vf /pkgs/drbd-utils/* /usr-local-bin/
fi
