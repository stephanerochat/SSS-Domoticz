#!/bin/bash

# PARAMS
# 1 : enable | disable | check
# 2 : ID(s) of camera(s), if more than one (Only for enable and disable actions) : coma separed (eg : 1,4)
# 3 : IDx of domoticz dummy switch

# No idx given = stop script
[[ -z "$1" ]] && { echo "Parameter 1 is empty" ; exit 1; }
[[ -z "$2" ]] && { echo "Parameter 2 is empty" ; exit 1; }
[[ -z "$3" ]] && { echo "Parameter 3 is empty" ; exit 1; }

# User defined vars
syno_user="USER"
syno_pwd="PWD"
syno_url="IP_SYNO:PORT_SYNO" # eg 192.168.1.100:5000
domoticz_url="IP_DOMOTICZ:PORT_DOMOTICZ" # eg 127.0.0.1:8080
vAuth=4
vCam=8
vList=1


# Get Paths (recommended by Synology for further update)
curlResult=$(curl -s "http://${syno_url}/webapi/query.cgi?api=SYNO.API.Info&method=Query&version=1&query=SYNO.API.Auth,SYNO.SurveillanceStation.Camera")
authPath=$(echo "$curlResult" | jq -r '.["data"]["SYNO.API.Auth"]["path"]')
surveillancePath=$(echo "$curlResult" | jq -r '.["data"]["SYNO.SurveillanceStation.Camera"]["path"]')

# Do login
curlResult=$(curl -s "http://${syno_url}/webapi/${authPath}?api=SYNO.API.Auth&method=login&version=${vAuth}&account=${syno_user}&passwd=${syno_pwd}&session=SurveillanceStation&format=sid")
if [[ $(echo "$curlResult" | jq -r '.["success"]') == 'false' ]]; then 
	echo "Error on login"
	exit 0
fi
# Storage of SID for further actions
SID=$(echo "$curlResult" | jq -r '.["data"]["sid"]')

# Do actions
# Enable action
if [[ $1 == 'enable' ]]; then
	# Enable trough DSM API
	curlResult=$(curl -s "http://${syno_url}/webapi/${surveillancePath}?api=SYNO.SurveillanceStation.Camera&method=Enable&version=${vCam}&cameraIds=${2}&_sid=${SID}")
	if [[ $(echo "$curlResult" | jq -r '.["success"]') == 'false' ]]; then 
		curl -s "http://${syno_url}/webapi/${authPath}?api=SYNO.API.Auth&method=logout&version=${vAuth}&_sid=${SID}" > /dev/null 2>&1
		echo "Error on enabling"
		exit 0
	fi

# Disable action
elif [[ $1 == 'disable' ]]; then
	# Enable trough DSM API
	curlResult=$(curl -s "http://${syno_url}/webapi/${surveillancePath}?api=SYNO.SurveillanceStation.Camera&method=Disable&version=${vCam}&cameraIds=${2}&_sid=${SID}")
	if [[ $(echo "$curlResult" | jq -r '.["success"]') == 'false' ]]; then 
		curl -s "http://${syno_url}/webapi/${authPath}?api=SYNO.API.Auth&method=logout&version=${vAuth}&_sid=${SID}" > /dev/null 2>&1
		echo "Error on disabling"
		exit 0
	fi

# Check action
elif [[ $1 == 'check' ]]; then
	# Get status of the camera
	curlResult=$(curl -s "http://${syno_url}/webapi/${surveillancePath}?api=SYNO.SurveillanceStation.Camera&method=List&version=${vList}&cameraIds=${2}&_sid=${SID}")
	# Get status of the dummy switch
	curlResultDomo=$(curl -s "http://${domoticz_url}/json.htm?type=devices&rid=${3}")
	# Cam is Off and dummy is On
	if [ $(echo "$curlResult" | jq -r '.data.cameras[].enabled') == 'false' ] && [ $(echo "$curlResultDomo" | jq -r '.result[].Status') == 'On' ]; then 
		curl -s "http://${domoticz_url}/json.htm?type=command&param=udevice&idx=${3}&nvalue=0&svalue=" > /dev/null 2>&1
	# Cam is On and dummy is Off
	elif [ $(echo "$curlResult" | jq -r '.data.cameras[].enabled') == 'true' ] && [ $(echo "$curlResultDomo" | jq -r '.result[].Status') == 'Off' ]; then 
		curl -s "http://${domoticz_url}/json.htm?type=command&param=udevice&idx=${3}&nvalue=1&svalue=" > /dev/null 2>&1
	fi
fi

# Do logoff
curl -s "http://${syno_url}/webapi/${authPath}?api=SYNO.API.Auth&method=logout&version=${vAuth}&_sid=${SID}" > /dev/null 2>&1
