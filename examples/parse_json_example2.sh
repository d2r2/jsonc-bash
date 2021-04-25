#!/bin/bash

#
# MIT License
#
# Copyright (c) 2021 Denis Dyakov <denis.dyakov@gma**.com>
#
# Inspired by minimalistic JSON parser written
# by Serge Zaitsev: https://github.com/zserge/jsmn.
# This code can be considered rewritten from
# the original project with some modifications.
#
# Support standard JSON, as well as its superset -
# JSONC (JSON with comments). Parsing comply with
# JSON standard and allow comments (JSONC extension).
#

# Load JSON library
source ../json.sh

# Function return JSON sample with comments (JSONC)
get_json_struct() {
	cat <<-EOF
{
    // JSON file with comments (JSONC)
    "main": {
        // Download, compile and install usb-modeswitch from source
        //"install_usbmodeswitch": true,

        // Download, compile and install usb-modeswitch-data from source
        //"install_usbmodeswitchdata": true,

        /*
        // Build /etc/network/interfaces file for Debian systems
        // to configure network interfaces
        */
        "deploy_network_settings": true,

        /*
           Install hostapd to run in Access Point mode.
           Can deploy patched version of hostapd binaries to forcebly
           enable 802.11n 40MHz bandwidth mode (channel bonding).
        */
        "install_hostapd": true,

        // Update /etc/hostapd.conf file according to wifi interface found in device
        "deploy_hostapd_settings": true,

        // Install local dns/dhcp server for home network
        "install_dnsmasq": true,
        "deploy_dnsmasq_settings": true,

        // Enable web proxy service for http/https connections.
        // Start minimal http server to serve Web Proxy Auto-Discovery Protocol (WPAD)
        "deploy_proxy": true
    },

    // Web proxy settings to configure WPAD with FindProxyForURL javascript function
    "webproxy": {
        "http": [
                    { "server": "192.168.1.60", "port": 8888 }
                ],
        "exceptions": [
                    // Add extra backslash to string, since it will be eliminated on HEREDOC expansion
                    { "url": "\\\\.microsoft\\\\.com(:\\\\d+)?", "description": "Skip proxy for URL" }
                ]
    }
}
	EOF
}


echo "-----------------------------"
echo "Original JSON/JSONC to parse:"
echo "-----------------------------"
get_json_struct

parse_json_from_pipe < <(get_json_struct); retval=$?
if [[ $retval -ne 0 ]]; then
	echo "Error parsing JSON in line $JSON_LINE_ERROR" 1>&2
	exit 1
fi

# Uncomment next few lines for debug purpose
echo "----------------------------------------------------------"
echo "Print JSON/JSONC parse result internals for debug purpose:"
echo "----------------------------------------------------------"
print_json_tokens

