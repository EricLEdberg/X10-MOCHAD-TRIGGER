# X10-MOCHAD-TRIGGER

Monitor X10 CM15 Mochad process & trigger remote APIs


This program monitors the output of the X10 CM15 Mochad process and triggers remote actions using cURL WebThings API when configured X10 ON or X10 OFF events occur.  The initial goal is to trigger WebThings events when someone presses an X10 RF or PL button.

This program was designed to interact with a WebThings IOT Gateway using it's cURL API to trigger events on the gateway.  It can easily be upgraded to trigger other IOT home controllers that support remote APIs.  In my home all services run on a single RPI 2b computer.

Dependencies

This program depends on:

-  A working X10 CM15 or CM19 (not tested) controller
-  The Mochad program running on a server directly connected to the X10 controller over USB.  Mochad allows other programs to initiate commands on the X10 controller or monitor X10 events that occur.
-  A server running the X10 Mochad Trigger program that monitors the output of Mochad
-  A working WebThings Gateway with an API key allowing remote management

Installation

-  Install Mochad & manually test X10 controller
-  Generate WebThings API Key
-  Identify WebThings IDs
-  Customize: x10-mochad-config.txt
-  Customize: x10-mochad.sh
-  Manually test:  x10-mochad.sh
-  Configure & execute:  ./x10-mochad-start.sh
-  Configure crontab to start process @reboot

