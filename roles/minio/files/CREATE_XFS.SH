#!/bin/bash

# Get the current hostname of the system
current_hostname=$(hostname)

# Prompt the user to input the hostname to proceed
read -p "Please enter the hostname of this system to proceed: " input_hostname

# Check if the input hostname matches the current system hostname
if [[ "$input_hostname" != "$current_hostname" ]]; then
  echo "Error: The entered hostname does not match the system hostname."
  echo "Exiting script..."
  exit 1
else
  echo "Hostname confirmed. Proceeding with the script..."
fi

# Get the list of all sd disks
disks=$(lsblk -dn -o NAME | grep '^sd')
counter=1  # Initialize counter for disk labels

for disk in $disks; do
  # Assign a unique label
  label="disk${counter}"
  
  # Check if the disk is mounted and unmount if necessary
  mountpoint=$(lsblk -no MOUNTPOINT /dev/${disk})
  if [[ -n "$mountpoint" ]]; then
    echo "Unmounting /dev/${disk} from ${mountpoint}..."
    umount /dev/${disk}
  fi

  # Wipe the existing partition table to avoid conflicts
  echo "Wiping the partition table on /dev/${disk}..."
  wipefs -a /dev/${disk}

  # Create a new partition table and partition
  echo "Partitioning /dev/${disk}..."
  parted -s /dev/${disk} mklabel gpt mkpart primary xfs 0% 100%

  # Reload partition table
  partprobe /dev/${disk}

  # Format the disk with XFS and label it
  echo "Formatting /dev/${disk} with XFS and label ${label}..."
  mkfs.xfs -L ${label} /dev/${disk} -f

  # Create a mount point based on the label
  mount_point="/mnt/${label}"
  mkdir -p $mount_point

  # Mount the disk using the label
  echo "Mounting /dev/${disk} at ${mount_point}..."
  mount /dev/disk/by-label/${label} $mount_point

  # Check if the disk is already in /etc/fstab
  if ! grep -qs "/dev/disk/by-label/${label}" /etc/fstab; then
    # Add the mount to /etc/fstab if not already present
    echo "Adding /dev/disk/by-label/${label} to /etc/fstab..."
    echo "/dev/disk/by-label/${label} ${mount_point} xfs defaults,noretry 0 0" >> /etc/fstab
  else
    echo "/dev/disk/by-label/${label} is already in /etc/fstab, skipping."
  fi

  # Increment the counter for the next disk label
  counter=$((counter + 1))
done

# Reload the systemd daemon to apply changes to /etc/fstab
systemctl daemon-reload
