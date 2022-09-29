#!/bin/bash -x
## Maintainer Alex Zheng <alex.zheng@daocloud.io>
## This is a wrapper scripts to have drbd9 containers automatically adapt host distros

## Check if image matches os type
which lbdisttool.py

image_dist="$(lbdisttool.py -l | awk -F'.' '{print $1}' )"
host_dist="$(lbdisttool.py -l --os-release /etc/host-release | awk -F'.' '{print $1}' )"

# For Kylin v10
if [ -z $image_dist ] \
   && grep -i "kylin .* v10" /etc/os-release; then
   echo "Image distro is Kylin V10"
   image_dist=kylin10
fi

if [ -z $host_dist ] \
   && uname -r | grep -i '.ky10.' \
   && grep -i "kylin .* v10" /etc/host-release; then
   echo "Host distro is Kylin V10"
   host_dist=kylin10
fi

# For DaemonSet: Gracefully exit for distro mismatch, so that next initContainer may start
# For Job: Exit failure
if [[ $host_dist != $image_dist ]]; then 
   echo "Image type does not match OS type, skip !" 
   [[ $LB_SKIP == 'yes' ]] && exit 0 || exit 1
fi

## Unload current drbd modules from kernel if it is lower than the target version 
# (only possible if no [drbd_xxx] process is running)
RUNNING_DRBD_VERSION=$( cat /proc/drbd | awk '/^version:/ {print $2}' )

if [ -z $RUNNING_DRBD_VERSION ]; then
   echo "No DRBD Module is loaded"
elif [[ $RUNNING_DRBD_VERSION == $DRBD_VERSION ]] || \
     [[ $( printf "$RUNNING_DRBD_VERSION\n$DRBD_VERSION" | sort -V | tail -1 ) != $DRBD_VERSION ]]
then
   echo "The loaded DRBD module version is already $RUNNING_DRBD_VERSION"
else 
   echo "The loaded DRBD module version $RUNNING_DRBD_VERSION is lower than $DRBD_VERSION"
   if [[ $LB_UPGRADE == 'yes' ]] || [[ $RUNNING_DRBD_VERSION =~ ^8 ]]; then
      for i in drbd_transport_tcp drbd; do
         if lsmod | grep -w $i; then
            rmmod $i || true
         fi
      done
   fi
fi

## Main Logic
# If no shipped module is found, then compile from source
if LB_HOW=shipped_modules bash -x /entry.sh; then
   echo "Successfully loaded shipped module"
elif LB_HOW=compile bash -x /entry.sh; then
   echo "Successfully loaded compiled module"
fi

# Drop modules to the host so it can independently load from OS
if [[ $LB_DROP == yes ]]; then

   # drop modules
   if [[ $host_dist =~ rhel ]]; then
      KODIR="/lib/modules/$(uname -r)/extra/drbd"
   elif [[ $host_dist =~ bionic|focal|jammy ]]; then
      KODIR="/lib/modules/$(uname -r)/updates/dkms/drbd"
   else
      KODIR="/lib/modules/$(uname -r)/drbd"
   fi 
   mkdir -vp "$KODIR"
   cp -vf /tmp/ko/*.ko "${KODIR}/"

   # register modules
   depmod -a

   # onboot load modules 
   cp -vf /pkgs/drbd.modules-load.conf /etc/modules-load.d/drbd.conf
   cp -vf /pkgs/drbd.modules /etc/sysconfig/modules/

   # drop drbd utils and set up conf directories
   cp -vf /pkgs/utils/* /usr-local-bin/
   cat /pkgs/drbd.conf > /etc/drbd.conf
   cp -vf /pkgs/global_common.conf /etc/drbd.d/
   
fi

# Check if DRBD is loaded correctly
if [[ $( cat /proc/drbd | awk '/^version/ {print $2}' ) != $DRBD_VERSION ]]; then
   echo "ERROR: DRBD is NOT loaded with the right version"
   exit 1
fi

# Check if hostname is the same as k8s node name
# With `hostNetwork`, container `hostname` cmd result is from host /proc/sys/kernel/hostname and /proc/sys/kernel/domainname 
if [[ $LB_CHECK_HOSTNAME == 'yes' ]] && [[ $(hostname) != $NODE_NAME ]]; then
   echo "ERROR: Hostname does not match K8s node name!"
   exit 1
fi 

exit 0
