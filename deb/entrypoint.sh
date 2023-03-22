#!/bin/bash

set -ex

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
    gpg --batch --passphrase '' --quick-gen-key 'ProtonMail Bridge' default default never
    pass init "ProtonMail Bridge"

    # Login
    protonmail-bridge --cli

else

     # socat will make the conn appear to come from 127.0.0.1
    # ProtonMail Bridge currently expects that.
    # It also allows us to bind to the real ports :)
    socat TCP-LISTEN:25,fork TCP:127.0.0.1:1025 &
    #socat TCP-LISTEN:143,fork TCP:127.0.0.1:1143 &
    # Use socat to transfer data between the IMAP server and the local publish port
    socat TCP4-LISTEN143,fork SSL:127.0.0.1:1143,verify=0 \
    EXEC:"echo 'IDLE' ; sleep 1 ; echo DONE",pty,ctty 
    # Start protonmail
    # Fake a terminal, so it does not quit because of EOF...
    rm -f faketty
    mkfifo faketty
    cat faketty | protonmail-bridge --cli
fi
