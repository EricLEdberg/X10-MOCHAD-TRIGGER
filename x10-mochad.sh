#!/bin/bash
# Note:  can't use bash -e as root shell will exit if any commands in the program fail.


# ---------------------------------------------------------------------------
# 
# Author:  Eric L. Edberg, ele@EdbergNet.com 12/2020
#
# Program Dependencies:
#  A running "mochad" process communicating to X10 USB port.  Can be co-resident on RPI.
#  netcat installed.   sudo apt install netcat
#
# Automatically start this program after a system reboot.
# Create a new contab entry with this line:
#
# @reboot /path/to/mochad/x10-mochad-start.sh
#
# v0.41 
# ---------------------------------------------------------------------------
export MYDEBUG=""

PROG_PATH="`dirname \"$0\"`"                # could be relative
PROG_PATH="`( cd \"$PROG_PATH\" && pwd )`"  # now its absolute

# ---------------------------------------------------------------------------
# Customize configuration settings
# ---------------------------------------------------------------------------
export MOCHAD_SERVER="127.0.0.1 1099"

# URL to WebThings GW
export WTGW_URL="http://127.0.0.1:8080"
# WebThings authorization key
export WTGW_AKEY="eyJhbGciOiJFUzI1NiAtNDA3NC1hOGQxLTY4YjU2MTIxMWNhZSJ9.eyJyb2xlIjoidXNlcl90b2tlbiIsImlhdCI6MTYwODU3NjYxNCwiaXNzIjoiTm90IHNldC4ifQ.tKo5n6cZGJgzPHoU8AVWAEIZJU1fld41W_Ykf4BD5jEd4Kpw36EnRHyZnT_BQrrjdwno3O80sSNn2yGjRZTrnQ"


# Associative array, index key: x10id-x10prop-x10val, storing epoch seconds since last time cmd was executed.
# Prevent multiple events submitted quickly in succession due to X10 tranceivers duplicating commands
declare -A SETPROPERTY_HIST_DATE
# number of seconds when duplicated (transcoded X10 commands) commands will not be processed
export SETPROPERTY_HIST_SEC=5


export X10_MOCHAD_CONFIG="${PROG_PATH}/x10-mochad-config.txt"
export X10_MOCHAD_LOGDIR="${PROG_PATH}"

export NETCAT="/bin/nc"
export NETCAT_LOG="${X10_MOCHAD_LOGDIR}/nc-log.txt"
export NETCAT_DEVICE_LOG="${X10_MOCHAD_LOGDIR}/nc-devices-log.txt"

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

if cd ${X10_MOCHAD_LOGDIR}
then : #continue
else    
    echo "$0: ERROR: can't cd to: ${X10_MOCHAD_LOGDIR}"
    exit 1
fi

if [ ! -e "${NETCAT}" ]
then
    echo "$0: ERROR: netcat program does not exist: ${NETCAT}:   sudo apt install netcat"
    exit 1
fi

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
TIMESTAMP() {
    echo "`date +'%m/%d %H:%M:%S'`"
}

# ---------------------------------------------------------------------------
# X10 - WebThing ID configuration file map
# Associative arrays used to store values, indexed by X10 ID
# ---------------------------------------------------------------------------
declare -A X10_X10ID
declare -A X10_WTID
declare -A X10_PROP
declare -A X10_VALON
declare -A X10_VALOFF

# read/parse configuration into associative arrays index by X10 ID
# Ugly and not  efficient but it works
X10_WEBTHINGS_READ_CONFIG() {
    
    if [ ! -s ${X10_MOCHAD_CONFIG} ]
    then
        echo "ERROR: ${X10_MOCHAD_CONFIG} does not exist"
        exit 1
    fi

    local xLine

    while read xLine 
    do
        [ -n "${MYDEBUG}" ] && echo "xLine: ${xLine}"

        if echo ${xLine} | grep "^#" > /dev/null
        then continue # next line
        fi
        [ -z ${xLine} ] && continue

        f1="`echo $xLine | cut -d';' -f1`"
        f2="`echo $xLine | cut -d';' -f2`"
        f3="`echo $xLine | cut -d';' -f3`"
        f4="`echo $xLine | cut -d';' -f4`"
        f5="`echo $xLine | cut -d';' -f5`"
        
        X10_X10ID[${f1}]=$f1
        X10_WTID[${f1}]=$f2
        X10_PROP[${f1}]=$f3
        X10_VALON[${f1}]=$f4
        X10_VALOFF[${f1}]=$f5

    done < ${X10_MOCHAD_CONFIG}

}

# ---------------------------------------------------------------------------
# netcat logs the output from the mochad process into a local file.
# Other processes then tail the log file and parse data accordingly.
# Cannot pipe output of netcat directly into other programs (awk or while read line) as file descriptors cause read problems
# ---------------------------------------------------------------------------
export NETCAT_PID=""
NETCAT_GETPID() {
    NETCAT_PID="`ps -aef | grep \"${NETCAT} ${MOCHAD_SERVER}\" | grep -v grep | awk '{print $2}' -`"
    if [ -z "$NETCAT_PID" ]
    then 
        echo "$(TIMESTAMP): NETCAT_GETPID(): netcat process does not exist?"
        NETCAT_PID=""
        return
    fi
    echo "$(TIMESTAMP): NETCAT_GETPID():  pid: ${NETCAT_PID}"
    return
}
NETCAT_START() {

    if NETCAT_STOP
    then : #continue
    else
        echo "$(TIMESTAMP): NETCAT_START(): cannot stop currently running logger. Will not start another one."
        return
    fi

    nohup ${NETCAT} ${MOCHAD_SERVER} >> ${NETCAT_LOG} 2>&1 &
    NETCAT_PID="${!}"
    echo "${NETCAT_PID}" > ${X10_MOCHAD_LOGDIR}/netcat-pid.txt
    echo "$(TIMESTAMP): NETCAT_START(): Starting new netcat logger, pid: ${NETCAT_PID}, server: ${MOCHAD_SERVER}"
    return
}
NETCAT_STOP() {
    
    if NETCAT_GETPID
    then : #continue
    else
        # If we can't determine PID is must not be running?
        return
    fi

    echo "$(TIMESTAMP): NETCAT_STOP(): Stopping currently-running netcat logger, pid: ${NETCAT_PID}"
    
    if kill -9 ${NETCAT_PID}
    then return
    fi

    return
}

X10MOCHAD_STOP(){
    local thispid=$$

    # get pid(s) of parent and child process
    if ps -aef | grep "x10-mochad.sh" | grep -v ${thispid} | grep -v grep > ${X10_MOCHAD_LOGDIR}/x10-mochad-pids.txt
    then : #continue
    else
        echo "$(TIMESTAMP): X10MOCHAD_STOP: previous x10-mochad.sh does not appear to be running, no need to stop it I guess"
        return
    fi
    xpids="`awk -v ORS=\" \" '/x10-mochad.sh/{print $2}' ${X10_MOCHAD_LOGDIR}/x10-mochad-pids.txt`"
    echo "$(TIMESTAMP): X10MOCHAD_STOP:  killing xpids: ${xpids}"
    if kill -15 ${xpids}
    then return
    fi

    return
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

WTGW_SETPROPERTY() {

    local _x10id="$1"
    local _x10btn="$2"  
    
    [ -z "${_x10id}" ]  && return
    [ -z "${_x10btn}" ] && return

    if echo ${_x10id} | egrep "\b([A-P][1-9]|[A-P]1[0-6])\b" > /dev/null
    then : #continue
    else return
    fi

    # X10 id is not defined in configuration file
    local _tmp="${X10_X10ID[$_x10id]}"
    if [ -z  "${_tmp}" ]
    then
        echo "$(TIMESTAMP): WTGW_SETPROPERTY  x10 id: ${_x10id}, not defined in configuration map"
        return
    fi

    local _x10wtid="${X10_WTID[$_x10id]}"
    local _x10prop="${X10_PROP[$_x10id]}"
    local _x10valon="${X10_VALON[$_x10id]}"
    local _x10valoff="${X10_VALOFF[$_x10id]}"
    
    if [ "${_x10btn}" = "on" ]
    then _x10val="${_x10valon}"
    elif [ "${_x10btn}" = "off" ]
    then _x10val="${_x10valoff}"
    else return
    fi

    if [ -z ${_x10wtid} ] || [ -z ${_x10prop} ] || [ -z ${_x10val} ]
    then
        echo "$(TIMESTAMP): WTGW_SETPROPERTY ERROR: x10ADDR(${_x10id}) _x10wtid(${_x10wtid}), _x10prop(${_x10prop}), _x10val(${_x10val}), not formatted correctly"
        return
    fi

    # do not execute same command again if it executed in the last SETPROPERTY_HIST_SEC seconds
    local _key="${_x10id}-${_x10prop}-${_x10val}"
    local _epochcur="`date +%s`"
    local _epochprev="${SETPROPERTY_HIST_DATE[$_key]}"
    local _secdiff="-1"
    if [ -n "${_epochprev}" ] && [ -n "${_epochcur}" ]
    then
        _secdiff=$(expr $_epochcur - $_epochprev)
        if [ "${_secdiff}" -le "${SETPROPERTY_HIST_SEC}" ]
        then
            echo "$(TIMESTAMP): WTGW_SETPROPERTY: repeated-to-soon: _secdiff: ${_secdiff}, _epochcur: ${_epochcur}, _epochprev: ${_epochprev} "
            return
        fi
    fi 
    SETPROPERTY_HIST_DATE[${_key}]=${_epochcur}

    echo "$(TIMESTAMP): WTGW_SETPROPERTY executing: ${_x10id}:${_x10wtid}:${_x10prop}:${_x10val}"  

    local xTIMEOUT=" --connect-timeout 10 --max-time 30 "

    # This program ($$) crashed when a curl timeout occurs.
    # Read that if "bash -e" was the root shell it would terminate if any commands failed with "any" exit code.
    # The "-e" option was removed so this may not be an issue?
    # Just in case, place the curl program in a sub-shell to prevent issue during --max-time timeouts which occasionaly happen
    xRet=$(
        curl ${xTIMEOUT} \
        -H "Authorization:Bearer ${WTGW_AKEY}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -X PUT -d '{"'${_x10prop}'":'${_x10val}'}' \
        --insecure --silent --show-error \
        ${WTGW_URL}/things/${_x10wtid}/properties/${_x10prop} \
        > ${X10_MOCHAD_LOGDIR}/x10-mochad-curl-output.txt 2>&1
        _Exit=${?}
        echo "cURL exit (${_Exit})" >>${X10_MOCHAD_LOGDIR}/x10-mochad-curl-output.txt
        echo ${_Exit}
    )

    # Update date stamp at completion
    # Some commands take a long time to complete and may even time out
    # This could exceed SETPROPERTY_HIST_SEC seconds allowing commands that are repeated/mirrored by multiple 
    #   trancievers to execute "too soon"
    _epochcur="`date +%s`"
    SETPROPERTY_HIST_DATE[${_key}]=${_epochcur}

}

# ---------------------------------------------------------------------------
# start/restart netcat logging process
# ---------------------------------------------------------------------------
NETCAT_START


# ---------------------------------------------------------------------------
# kill x10-mochad.sh (this program) if it's currently running
# ---------------------------------------------------------------------------
X10MOCHAD_STOP

# ---------------------------------------------------------------------------
# Start monitoring!
# ---------------------------------------------------------------------------

# Read and parse X10 <-> WebThing configuration
X10_WEBTHINGS_READ_CONFIG

echo "$(TIMESTAMP): X10MOCHAD:  starting main loop monitoring for incoming x10 events"

_x10id=""
_x10houseunit=""
_x10housecode=""
_x10button=""

tail --lines=0 -f ${NETCAT_LOG} | while read line
do
	[ -n "${MYDEBUG}" ] && echo "$(TIMESTAMP) ${line}"

    # Trigger when X10 controller receives single-line RF pushbutton presses
    # OR when the X10 controller transmits a scheduled Tx RF event
    # 01/28 17:50:39 Rx RF HouseUnit: C2 Func: On
    # 01/28 21:01:35 Tx RF HouseUnit: O10 Func: Off
    # 01/28 21:01:56 Rx RF HouseUnit: O9 Func: Off
    # 01/28 21:02:13 Rx RF HouseUnit: O9 Func: On

    if echo "${line}" | egrep "^[0-9][0-9]/[0-9][0-9].*[T|R]x [R|P].*HouseUnit:.*[A-P]([1-9]|1[0-6]) Func: O[n|f]" > /dev/null
    then
        _x10id="`echo ${line} | cut -d' ' -f6`"
        
        # was On or Off button pressed?
        if echo "${line}" | grep "Func: On" > /dev/null
        then  _x10button="on"
        elif echo "${line}" | grep "Func: Off" > /dev/null
        then _x10button="off"
        else
            echo "$(TIMESTAMP): SINGLELINE: ERROR, unknown Func: [on|off] value"
            continue   # next line
        fi      

        echo "$(TIMESTAMP): SINGLELINE:  _x10id: $_x10id, x10button: ${_x10button}"  
        WTGW_SETPROPERTY "${_x10id}" "${_x10button}"

        _x10id=""
        _x10housecode=""
        _x10houseunit=""
        _x10button=""

        continue  # next line
        
    # -----------------------------------------------------------------------------
    # Trigger when multi-line PL events are output from the X10 controller
    # First Line 1:   identify HouseUnit and Unit code
    # Line 1:   05/30 20:59:20 Tx PL HouseUnit: P1
    # Line 2:   05/30 20:59:20 Tx PL House: P Func: On
    # -----------------------------------------------------------------------------
    elif echo "${line}" | egrep "^[0-9][0-9]/[0-9][0-9].*[T|R]x [R|P].*HouseUnit:.*[A-P]([1-9]|1[0-6])" > /dev/null
    then
        _x10houseunit="`echo ${line} | cut -d' ' -f6 | cut -c1`"
        _x10housecode="`echo ${line} | cut -d' ' -f6 | cut -c2-3`"
        [ -n "${MYDEBUG}" ] && echo "MULTILINE Step 1:  _x10houseunit: $_x10houseunit, _x10housecode: $_x10housecode"

         continue # Next Line
    fi

    # -----------------------------------------------------------------------------
    # Trigger when multi-line PL events are output from the X10 controller
    # Next Line 2:  identify house code (number)
    # -----------------------------------------------------------------------------
    if [ -n "${_x10houseunit}" ] && [ -n "${_x10housecode}" ]
    then
        # Next Line 2:  identify if On or Off button
        # 05/30 20:59:20 Tx PL House: P Func: On
        if echo "${line}" | egrep "^[0-9][0-9]/[0-9][0-9].*[T|R]x [R|P].*House: [a-p|A-P] Func: O[n|f]" > /dev/null
        then

            if echo "${line}" | grep "Func: On" > /dev/null
            then  _x10button="on"
            elif echo "${line}" | grep "Func: Off" > /dev/null
            then _x10button="off"
            else
                echo "$(TIMESTAMP): MULTILINE:  ERROR, unknown mode for Func: [on|off] value"
                _x10id=""
                _x10housecode=""
                _x10houseunit=""
                _x10button=""
                continue  # next line
            fi

            echo "$(TIMESTAMP): MULTILINE:  _x10houseunit: $_x10houseunit, _x10housecode: $_x10housecode, x10button: ${_x10button}"  
            WTGW_SETPROPERTY "${_x10houseunit}${_x10housecode}" "${_x10button}"
        fi

        _x10id=""
        _x10housecode=""
        _x10houseunit=""
        _x10button=""

        continue  # next line
    fi


done
