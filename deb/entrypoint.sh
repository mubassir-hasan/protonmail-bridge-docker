#!/bin/bash

set -ex

# Start dbus and gnome-keyring
export $(dbus-launch)
echo "" | gnome-keyring-daemon --unlock --components=secrets

# Initialize
if [[ $1 == init ]]; then

    # # Parse parameters
    # TFP=""  # Default empty two factor passcode
    # shift  # skip `init`
    # while [[ $# -gt 0 ]]; do
    #     key="$1"
    #     case $key in
    #         -u|--username)
    #         USERNAME="$2"
    #         ;;
    #         -p|--password)
    #         PASSWORD="$2"
    #         ;;
    #         -t|--twofactor)
    #         TWOFACTOR="$2"
    #         ;;
    #     esac
    #     shift
    #     shift
    # done

    # Initialize pass
    gpg --generate-key --batch /protonmail/gpgparams
    pass init pass-key

    # Login
    protonmail-bridge --cli

else

    # Clean up stale lock files from previous runs
    rm -f /root/.cache/protonmail/bridge-v3/*.lock 2>/dev/null || true
    rm -f "/root/.cache/Proton AG/bridge-v3"/*.lock 2>/dev/null || true

    # socat will make the conn appear to come from 127.0.0.1
    # ProtonMail Bridge currently expects that.
    # It also allows us to bind to the real ports :)
    socat TCP-LISTEN:25,fork TCP:127.0.0.1:1025 &
    socat TCP-LISTEN:143,fork TCP:127.0.0.1:1143 &

    # Start protonmail
    # Fake a terminal, so it does not quit because of EOF...
    # Use a loop so that when a pipe writer disconnects (EOF), cat restarts
    # and the bridge CLI keeps running without interruption.
    rm -f faketty
    mkfifo faketty
    while true; do cat faketty; done | protonmail-bridge --cli

fi
