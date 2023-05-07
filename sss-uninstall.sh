##!/bin/bash                                                                                                                                   
#
# Usage: 
#    sudo bash ./sss-uninstall.sh
#

CONF_DIR="/etc/sss/"
SYSTEMD_DIR="/etc/systemd/system/"
BIN_DIR="/usr/local/bin/"

targets=($(ls ${CONF_DIR}*.json))
for target in "${targets[@]}";
do
    service=${target##*/}
    service=${service%.*}
    systemctl stop $service
    systemctl disable $service
    rm $SYSTEMD_DIR$service.service
done

rm -rf $CONF_DIR
if [ -f ${BIN_DIR}sss-server ]; then
    rm ${BIN_DIR}sss-server
fi
if [ -f ${BIN_DIR}sss-client ]; then
    rm ${BIN_DIR}sss-client
fi
