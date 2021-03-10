# X10-MOCHAD-TRIGGER

Monitor X10 CM15 Mochad process & trigger remote APIs


This program monitors the output of the X10 CM15 Mochad process and triggers remote actions using cURL WebThings API when configured X10 ON or X10 OFF events occur.  The initial goal is to trigger WebThings events when someone presses an X10 RF or PL button.

This program was designed to communicate with a WebThings.io Gateway using it's cURL API to alter thing properties.  It can easily be upgraded to interact with other IOT home controllers that support remote APIs.  In my home, all services run on a single RPI 2b computer.

<h2>Dependencies</h2>

This program depends on:

-  A working X10 CM15 or CM19 (not tested) controller
-  The Mochad program running on a server directly connected to the X10 controller over USB.  Mochad allows other programs to initiate commands on the X10 controller or monitor X10 events that occur.
-  A server running the X10 Mochad Trigger program that monitors the output of Mochad
-  A working WebThings Gateway with an API key allowing remote management

<h2>Installation</h2>
-  Install Mochad & manually test X10 controller
-  Generate WebThings API Key
-  Identify WebThings IDs
-  Customize: x10-mochad-config.txt
-  Customize: x10-mochad.sh
-  Manually test:  x10-mochad.sh
-  Configure & execute:  ./x10-mochad-start.sh
-  Configure crontab to start process @reboot

<h2>Install Mochad</h2>
Mochad is a program that communicates on a USB port to an X10 CM15 or X10 CM19 controller.  It also listens for incoming TCP connections on port 1099 for remote connections.  Mochad will output all scheduled commands that the X10 controller executes or commands it recieves or it's PL or RF interface.  It also accepts commands sent by remote applications and submits them to the X10 controller for execution.  Mochad will happily execute on a Raspberry PI along with other USB components.

    - git clone Mochad from HERE
        This version of Mochad was modified to fix a bug.  See readme for details.
    - Follow these instructions HERE to make and install Mochad
        You may need to install make environment necessary to compile mochad.  
    - Plug the X10 controller into the USB port & verify that the mochad services started
        ps -aef | grep mochad
    - Use netcat to test mochad is working:
        echo "st" | nc 127.0.0.1 1099                 # should return a list of X10 devices identified by the controller
        echo "PL A10 OFF" | nc 127.0.0.1 1099         # Turn a test X10 device A10 OFF.  Customize!.
    - Do not proceed until netcat can successfully commuinicate to the X10 controller

<h2>Generate WebThings API Key</h2>
Create a Webthings authorization key.  This is required to authorize remote applications to execute commands.  This key is hard-coded in the x10-mochad.sh program.
    - WebThings -> Settings -> Authorizations
        Hint:  Copy the authorization key before closing the form

<h2>Identify WebThing Thing IDs You Want To Control</h2>