#! /usr/bin/env bash

# Set the location for the installation.
INSTALL_DIR="/opt/service-scheduler"

# Check if we are root.
if [ "$(whoami)" != "root" ]
then
  echo -e "\nERROR: This script must be run as user root.\n"
  exit 1
fi

echo -e "Running setup on $INSTALL_DIR"
# Ensure that the directories are present.
[ -d "$INSTALL_DIR" ] || {
  echo "Creating directory $INSTALL_DIR."
  mkdir "$INSTALL_DIR"
}

function install_file() {
  SOURCE="$1"
  TARGET="$2/$1"
  MODE="$3"

  # Ensure that the script is present.
  if [ ! -f "$TARGET" ]
  then
    echo "Creating file $TARGET."
    cp "$SOURCE" "$TARGET"
  else
    # Generate checksums for the source and target files.
    CHECKSUM_SOURCE=$(md5sum "$SOURCE" | cut -f1 -d' ')
    CHECKSUM_TARGET=$(md5sum "$TARGET" | cut -f1 -d' ')

    # Check if the checksums are a match.
    if [ "$CHECKSUM_SOURCE" != "$CHECKSUM_TARGET" ]
    then
      echo "Updating file $TARGET."
      cp "$SOURCE" "$TARGET"
    fi
  fi

  # Check if the filemode is set correctly.
  if [ "$(stat -c %a """$TARGET""")" != "$MODE" ]
  then
    echo "Setting permissions for $TARGET to $MODE."
    chmod "$MODE" "$TARGET"
  fi
}

install_file servicescheduler.sh $INSTALL_DIR 750
install_file settings.json $INSTALL_DIR 640
install_file servicescheduler.service /lib/systemd/system 644

# Convert INSTALL_DIR so sed can use it.
T_INSTALL_DIR=$(echo "$INSTALL_DIR" | sed 's/\//\\\//g')

echo -e "Updating settings."
sed -i "s/^WorkingDirectory=.*/WorkingDirectory=$T_INSTALL_DIR/" /lib/systemd/system/servicescheduler.service
sed -i "s/^ExecStart=.*/ExecStart=$T_INSTALL_DIR\/servicescheduler.sh/" /lib/systemd/system/servicescheduler.service
systemctl daemon-reload

# Ensure that the service is enabled.
systemctl is-enabled servicescheduler &> /dev/null || {
  echo -e "Enabling service."
  systemctl enable servicescheduler
}

# Ensure that the service is running.
systemctl is-active servicescheduler &> /dev/null || {
  echo -e "Starting service."
#  systemctl start servicescheduler
}

echo -e "Setup completed successfully."
