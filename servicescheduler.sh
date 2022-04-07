#! /usr/bin/env bash

# Set the location of the configuration file.
CONFIG="settings.json"

function log() {
  # Function that writes log messages.

  # Set the message.
  MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"

  # Only write to log file if we are not running as a daemon.
  if [ "$DAEMON" == 0 ] || [ -z "$DAEMON" ]
  then
    echo -e "$MESSAGE"
  else
    echo -e "$MESSAGE" >> "$LOGFILE"
  fi
}

function error() {
  # Function that writes error messages.

  # Set the message.
  MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1"

  # Only write to log file if we are not running as a daemon.
  if [ "$DAEMON" == 0 ] || [ -z "$DAEMON" ]
  then
    echo -e "$MESSAGE"
  else
    echo -e "$MESSAGE" >> "$LOGFILE"
  fi

  # Check if a second argument has been passed to kill the script.
  if [ -n "$2" ]
  then
    log "Killing script with exit code '$2'."
    exit "$2"
  fi
}

function validate_date() {
  # Function that validates a date.

  # Check if the date is valid.
  if [ -z "$1" ]
  then
    error "Date is empty."
    RETVAL=2
  elif date -d "${*}" &> /dev/null
  then
    RETVAL=0
  else
    error "Date '${*}' is invalid."
    RETVAL=1
  fi

  # Return result.
  return $RETVAL
}

function check_dayofweek() {
  # Set the default return value.
  RETVAL=0

  # Loop over the day of the week to see if the services must be enabled or disabled.
  COUNTER=0
  while [ "$COUNTER" -lt "$(jq -r '.dayofweek | length' $CONFIG)" ]
  do
    # Get the day of the week from the list.
    DOW=$(jq -r ".dayofweek[$COUNTER]" $CONFIG)

    # Test if the day matches the current day of the week.
    if [ "$(date +%w)" == "$DOW" ]
    then
      # Set flag to disable the services.
      log "Day of week $DOW found"
      RETVAL=1
    fi

    # Update the counter.
    COUNTER=$((COUNTER + 1))
  done

  return $RETVAL
}

function check_schedules() {
  # Set default return value.
  RETVAL=0

  # Loop over schedules to see if the services must be enabled or disabled.
  COUNTER=0
  while [ "$COUNTER" -lt "$(jq -r '.schedules | length' $CONFIG)" ]
  do
    # Set a variable to track if the schedule is valid.
    INVALIDATE_SCHEDULE=0

    # Get the data for the current schedule.
    NAME=$(jq -r ".schedules[$COUNTER].name" $CONFIG)
    FROM_DATE=$(jq -r ".schedules[$COUNTER].from.date" $CONFIG)
    FROM_TIME=$(jq -r ".schedules[$COUNTER].from.time" $CONFIG)
    TO_DATE=$(jq -r ".schedules[$COUNTER].to.date" $CONFIG)
    TO_TIME=$(jq -r ".schedules[$COUNTER].to.time" $CONFIG)

    [ "$NAME" == "null" ] && NAME="$COUNTER"
    [ "$FROM_DATE" == "null" ] && INVALIDATE_SCHEDULE=1
    [ "$FROM_TIME" == "null" ] && FROM_TIME=""
    [ "$TO_DATE" == "null" ] && INVALIDATE_SCHEDULE=1
    [ "$TO_TIME" == "null" ] && TO_TIME=""

    # Only process valid schedules.
    if [ "$INVALIDATE_SCHEDULE" == 0 ]
    then
      log "Processing schedule $NAME"

      # Get the current date.
      NOW=$(date +%s)

      # Consolidate date/time pairs.
      FROM=$(date -d "$FROM_DATE $FROM_TIME" +%s)
      TO=$(date -d "$TO_DATE $TO_TIME" +%s)

      # Validate date/time pairs.
      validate_date "@$FROM" || INVALIDATE_SCHEDULE=1
      validate_date "@$TO" || INVALIDATE_SCHEDULE=1

      # Continue only if the pairs are valid.
      if [ "$INVALIDATE_SCHEDULE" == 0 ]
      then
        # Test if NOW is in the schedule.
        if [ "$FROM" -lt "$NOW" ] && [ "$TO" -gt "$NOW" ]
        then
          log "Schedule $NAME matches current date."
          # Set the flag to ensure that the services are disabled.
          RETVAL=1
        fi
      else
        error "Schedule $NAME is not valid."
      fi
    else
      error "Schedule $NAME is not valid."
    fi

    # Increment the counter.
    COUNTER=$((COUNTER + 1))
  done

  return $RETVAL
}

function run_script() {
  # This function runs a script and evaluates it.
  SCRIPT="$1"

  # Set Logfiles for fetching the output.
  STDOUT=$(mktemp -p /dev/shm)
  STDERR=$(mktemp -p /dev/shm)

  # Run the script.
  $SCRIPT 1> "$STDOUT" 2> "$STDERR"

  # Store the exit code.
  EXITCODE="$?"

  # Check if the script ran successfully.
  if [ "$EXITCODE" == 0 ]
  then
    log "$(cat """$STDOUT""")" "$SCRIPT_LOGLEVEL"
  else
    error "Exitcode $EXITCODE returned after executing $SCRIPT"
    error "$(cat """$STDERR""")"
    error "STDOUT for $SCRIPT"
    error "$(cat """$STDOUT""")"
  fi

  # Ensure output files are absent.
  rm -f "$STDOUT" "$STDERR"

  # Return the exitecode.
  return "$EXITCODE"
}

function set_servicestate() {
  # Loop over all services and ensure that they are either running or disabled.
  COUNTER=0
  while [ "$COUNTER" -lt "$(jq -r '.services | length' $CONFIG)" ]
  do
    # Get the name of the service.
    SERVICE_NAME=$(jq -r ".services[$COUNTER].name" $CONFIG)

    # Test if the service should be started and enabled.
    log "Checking service $SERVICE_NAME."
    if [ "$ENABLE_SERVICES" == 0 ]
    then
      # Run pre scripts.
      C=0
      while [ "$C" -lt "$(jq -r """.services[$COUNTER].start.pre | length""" $CONFIG)" ]
      do
        # Get script from configuration.
        SCRIPT=$(jq -r ".services[$COUNTER].start.pre[$C]" $CONFIG)

        # Run the script.
        run_script "$SCRIPT" 

        # Update the counter.
        C=$((C + 1))
      done

      # Ensure that the service is enabled.
      systemctl is-enabled "$SERVICE_NAME" &> /dev/null || {
        log "Enabling service $SERVICE_NAME."
        systemctl enable "$SERVICE_NAME" &> /dev/null
      }

      # Ensure that the service is running.
      systemctl is-active "$SERVICE_NAME" &> /dev/null || {
        log "Starting service $SERVICE_NAME."
        systemctl start "$SERVICE_NAME" &> /dev/null
      }

      # Run post scripts.
      C=0
      while [ "$C" -lt "$(jq -r """.services[$COUNTER].start.post | length""" $CONFIG)" ]
      do
        # Get script from configuration.
        SCRIPT=$(jq -r ".services[$COUNTER].start.post[$C]" $CONFIG)

        # Run the script.
        run_script "$SCRIPT"

        # Update the counter.
        C=$((C + 1))
      done
    else
      # Ensure that the service is stopped and disabled.
      # Run pre scripts.
      C=0
      while [ "$C" -lt "$(jq -r """.services[$COUNTER].stop.pre | length""" $CONFIG)" ]
      do
        # Get script from configuration.
        SCRIPT=$(jq -r ".services[$COUNTER].stop.pre[$C]" $CONFIG)

        # Run the script.
        run_script "$SCRIPT"

        # Update the counter.
        C=$((C + 1))
      done

      # Ensure that the service is disabled.
      systemctl is-enabled "$SERVICE_NAME" &> /dev/null && {
        log "Disabling service $SERVICE_NAME."
        systemctl disable "$SERVICE_NAME" &> /dev/null
      }

      # Ensure that the service is stopped.
      systemctl is-active "$SERVICE_NAME" &> /dev/null && {
        log "Stopping service $SERVICE_NAME."
        systemctl stop "$SERVICE_NAME" &> /dev/null
      }

      # Run post scripts.
      C=0
      while [ "$C" -lt "$(jq -r """.services[$COUNTER].stop.post | length""" $CONFIG)" ]
      do
        # Get script from configuration.
        SCRIPT=$(jq -r ".services[$COUNTER].stop.post[$C]" $CONFIG)

        # Run the script.
        run_script "$SCRIPT"

        # Update the counter.
        C=$((C + 1))
      done
    fi

    # Update the counter.
    COUNTER=$((COUNTER + 1))
  done
}

function main() {
  # Test if we need to enable or disable services.
  # ENABLE_SERVICES=0 => Services should be running and enabled.
  # ENABLE_SERVICES=1 => Services should be stopped and disabled.
  if ! check_dayofweek
  then
    ENABLE_SERVICES=1
  elif ! check_schedules
  then
    ENABLE_SERVICES=1
  else
    ENABLE_SERVICES=0
  fi

  # Set state of the service(s).
  set_servicestate
}

# Check if we are root.
if [ "$(whoami)" != "root" ]
then
  error "This script must be run as user root." 1
fi

# Check if JQ is present.
command -v jq &> /dev/null || {
  error "JQ is not present. Please install JQ first." 1
}

# Check if the configuration file is valid.
jq -r '.' $CONFIG &> /dev/null || error "Configuration file $CONFIG is not valid." 1

# Get settings from configuration file.
LOGFILE=$(jq -r '.logfile' $CONFIG)
DAEMON=$(jq -r '.daemon' $CONFIG)
INTERVAL=$(jq -r '.interval' $CONFIG)

# Test if we are running as a daemon.
if [ "$DAEMON" == 1 ]
then
  # Start an endless loop.
  while true
  do
    main
    sleep "$INTERVAL"
  done
else
  main
fi
