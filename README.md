# Service-Scheduler

Service Scheduler is a BASH script that enables or disables services.

The scheduler is designed to stop services during events and start

them as soon as it they are allowed to run.

The scheduler allows for two types of schedules:
1) Day of the week. You can schedule services on fixed week days.
2) Scheduled events. You can schedule events that span several days.

## Installation
Clone the project to your local machine
```git clone git@github.com:Tendermint-Validators/Service-Scheduler.git
cd Service-Scheduler
```

(Optional) Create a branch for your configuration.

Customize the configuration file `settings.json` for your own needs.

Install the scheduler:
```./setup.sh```

## Configuration

### daemon
Options: (0|1)

0. Run the service checks one time and then quit the script.
1. Run the service checks in a loop so we can run as a background daemon.

### interval
Options: (n-seconds)

Sets the interval between service checks in seconds. Default setting is 60 seconds.

### logfile
Options: <filename>

Sets the location of the logfile.

### services
List of services that should be controlled by the script.

Options:
`name` (Mandatory) Name of the service as Systemd expects it.
`start.pre` (Optional) A list of scripts that must be run before starting the service.
`start.post` (Optional) A list of scripts that must be run after starting the service.
`stop.pre` (Optional) A list of scripts that must be run before stopping the service.
`stop.post` (Optional) A list of scripts that must be run after stopping the service.

### dayofweek
List of days of the week on which the service(s) should be stopped and disabled.
This list is optional. Please note that 0=Sunday and 6=Saterday.

### schedules
List of schedules that on which the service(s) should be stopped and disabled.

Options:
`name` (Optional) Name of the event.
`from.date` (Mandatory) Date on which the event starts.
`from.time` (Optional) Time on which the event starts.
`to.date` (Mandatory) Date on which the event stops.
`to.time` (Optional) Time on which the event stops.

Date format: YYYY-MM-DD
Time format: HH:MM:SS

Please note that all times are consolidated and converted to EPOCH via date. Times are
optional as date defaults to 00 when elements for time are not set.

HH is allowed and will default to HH:00:00
HH:MM is allowed and will default to HH:MM:00
Optionally HH:MM:SS is available to use but would require timing with the interval if you
need any sort of precision.
