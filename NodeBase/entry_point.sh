#!/bin/bash

source /opt/bin/functions.sh
/opt/selenium/generate_config > /opt/selenium/config.json

export GEOMETRY="$SCREEN_WIDTH""x""$SCREEN_HEIGHT""x""$SCREEN_DEPTH"

if [ ! -e /opt/selenium/config.json ]; then
  echo No Selenium Node configuration file, the node-base image is not intended to be run directly. 1>&2
  exit 1
fi

if [ -z "$HUB_PORT_4444_TCP_ADDR" ]; then
  echo Not linked with a running Hub container 1>&2
  exit 1
fi

function shutdown {
  kill -s SIGTERM $NODE_PID
  wait $NODE_PID
}

if [ ! -z "$REMOTE_HOST" ]; then
  >&2 echo "REMOTE_HOST variable is *DEPRECATED* in these docker containers.  Please use SE_OPTS=\"-host <host> -port <port>\" instead!"
  exit 1
fi

if [ ! -z "$SE_OPTS" ]; then
  echo "appending selenium options: ${SE_OPTS}"
fi

# TODO: Look into http://www.seleniumhq.org/docs/05_selenium_rc.jsp#browser-side-logs

SERVERNUM=$(get_server_num)

rm -f /tmp/.X*lock
mkdir -p /tmp/screen

#xvfb-run -a -n $SERVERNUM --server-args="-screen 0 $GEOMETRY -ac +extension RANDR -wr" \
xvfb-run -a -n $SERVERNUM -w 5 --server-args="-screen 0 $GEOMETRY -ac +extension RANDR -fbdir /tmp/screen -wr" \
  java -Dvideo.xvfbscreen=/tmp/screen ${JAVA_OPTS} -cp /opt/selenium/selenium-video-node.jar:/opt/selenium/selenium-server-standalone.jar \
    org.openqa.grid.selenium.GridLauncherV3 \
    -servlets com.aimmac23.node.servlet.VideoRecordingControlServlet \
    -proxy com.aimmac23.hub.proxy.VideoProxy \
    -role wd \
    -hub http://$HUB_PORT_4444_TCP_ADDR:$HUB_PORT_4444_TCP_PORT/grid/register \
    -nodeConfig /opt/selenium/config.json \
    ${SE_OPTS} &
NODE_PID=$!

trap shutdown SIGTERM SIGINT
wait $NODE_PID
