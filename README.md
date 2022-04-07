# Service-Scheduler

Service Scheduler is a BASH script that enables or disables services.<br>
The scheduler is designed to stop services during events and start<br>
them as soon as it they are allowed to run.<br>

The scheduler allows for two types of schedules:<br>
1) Day of the week. You can schedule services on fixed week days.<br>
2) Scheduled events. You can schedule events that span several days.<br>

## Installation
1. Clone the project to your local machine
```
git clone git@github.com:Tendermint-Validators/Service-Scheduler.git
cd Service-Scheduler
```
2. (Optional) Create a branch for your configuration.
```
git checkout -b production
```
3. Customize the configuration file `settings.json` for your own needs.
4. Install the scheduler: `./setup.sh`

## Configuration
All configuration settings can be found in `settings.json`. Please make sure<br>
to create a backup of this file after you are satisfied with your configuration<br>
to ensure that you don't loose it by overwriting.

### daemon
Options: (0|1)<br>
0. Run the service checks one time and then quit the script.
1. Run the service checks in a loop so we can run as a background daemon.

### interval
Options: (n-seconds)<br>
Sets the interval between service checks in seconds. Default setting is 60 seconds.

### logfile
Options: (filename)<br>
Sets the location of the logfile.

### services
List of services that should be controlled by the script.

Options:<br>
`name` (Mandatory) Name of the service as Systemd expects it.<br>
`start.pre` (Optional) A list of scripts that must be run before starting the service.<br>
`start.post` (Optional) A list of scripts that must be run after starting the service.<br>
`stop.pre` (Optional) A list of scripts that must be run before stopping the service.<br>
`stop.post` (Optional) A list of scripts that must be run after stopping the service.<br>

### dayofweek
List of days of the week on which the service(s) should be stopped and disabled.<br>
This list is optional. Please note that 0=Sunday and 6=Saterday.

### schedules
List of schedules that on which the service(s) should be stopped and disabled.<br>
Options:<br>
`name` (Optional) Name of the event.<br>
`from.date` (Mandatory) Date on which the event starts.<br>
`from.time` (Optional) Time on which the event starts.<br>
`to.date` (Mandatory) Date on which the event stops.<br>
`to.time` (Optional) Time on which the event stops.<br>

Date format: YYYY-MM-DD<br>
Time format: HH:MM:SS<br>

Please note that all times are consolidated and converted to EPOCH via date. Times are<br>
optional as date defaults to 00 when elements for time are not set.

HH is allowed and will default to HH:00:00<br>
HH:MM is allowed and will default to HH:MM:00<br>
Optionally HH:MM:SS is available to use but would require timing with the interval if you<br>
need any sort of precision.
