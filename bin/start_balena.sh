#!/bin/bash

run_setup () {
    mkdir -p \
        /data/.config \
        /data/.config/uzbl \
        /data/.screenly \
        /data/screenly \
        /data/screenly_assets

    cp -n /tmp/screenly/ansible/roles/screenly/files/screenly.conf /data/.screenly/screenly.conf
    cp -n /tmp/screenly/ansible/roles/screenly/files/screenly.db /data/.screenly/screenly.db
    cp -n /tmp/screenly/ansible/roles/screenly/files/uzbl-config /data/.config/uzbl/config-screenly

    cp -rf /tmp/screenly/* /data/screenly/

    if [ -n "${OVERWRITE_CONFIG}" ]; then
        echo "Requested to overwrite Screenly config file."
        cp /data/screenly/ansible/roles/screenly/files/screenly.conf "/data/.screenly/screenly.conf"
    fi

    # Set management page's user and password from environment variables,
    # but only if both of them are provided. Can have empty values provided.
    if [ -n "${MANAGEMENT_USER+x}" ] && [ -n "${MANAGEMENT_PASSWORD+x}" ]; then
        sed -i -e "s/^user=.*/user=${MANAGEMENT_USER}/" -e "s/^password=.*/password=${MANAGEMENT_PASSWORD}/" /data/.screenly/screenly.conf
    fi
}

run_viewer () {
    # By default docker gives us 64MB of shared memory size but to display heavy
    # pages we need more.
    umount /dev/shm && mount -t tmpfs shm /dev/shm

    while true; do

        /usr/bin/X 0<&- &>/dev/null &
        /usr/bin/matchbox-window-manager -use_titlebar no -use_cursor no 0<&- &>/dev/null &

        error=$(/usr/bin/xset s off 2>&1 | grep -c "unable to open display")
            if [[ "$error" -eq 0 ]]; then
            break
        fi

        echo "Still continue..."
        sleep 1
    done

    /usr/bin/xset -dpms
    /usr/bin/xset s noblank

    while true; do

        error=$(curl 127.0.0.1:8080 2>&1 | grep -c "Failed to connect")
            if [[ "$error" -eq 0 ]]; then
            break
        fi

        echo "Still continue..."
        sleep 1
    done

    /usr/bin/python /data/screenly/viewer.py
}

run_server () {
    service nginx start

    export RESIN_UUID=${RESIN_DEVICE_UUID}

    /usr/bin/python /data/screenly/server.py
}

run_websocket () {
    /usr/bin/python /data/screenly/websocket_server_layer.py
}

if [[ "$SCREENLYSERVICE" = "server" ]]; then
    run_setup
    run_server
fi

if [[ "$SCREENLYSERVICE" = "viewer" ]]; then
    run_viewer
fi

if [[ "$SCREENLYSERVICE" = "websocket" ]]; then
    run_websocket
fi
