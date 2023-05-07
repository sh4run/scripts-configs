##!/bin/bash 
#
# Usage: 
#    sudo bash ./sss-client.sh <server-ip> <client_cfg_string>
#

if [ -z "$2" ]
then
    echo "Usage:"
    echo "    sudo bash ./sss-client.sh <server-ip> <client_config_string>"
    echo ""
    exit 1
fi

if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
then
    echo "Usage:"
    echo "    sudo bash ./sss-client.sh <server-ip> <client_config_string>"
    echo ""
    exit 1
fi

client_cfg=$(echo $2 | base64 --decode 2>/dev/null)
if [ $? -ne 0 ]
then
    echo "Error found in client_cfg_string!"
    echo "Usage:"
    echo "    sudo bash ./sss-client.sh $1 <client_config_string>"
    echo ""
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
   echo "Usage:"
   echo "    sudo bash ./sss-client.sh $1 $2"
   echo ""
   exit 1
fi

#
# install jq to parse json
#
apt -yq install jq

declare -A cfg_params
while IFS=$'\t' read -r key value; do
    cfg_params[$key]=$value
done < <(jq -r 'to_entries[] | [.key, .value] | @tsv' <<< "$client_cfg")

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

CONF="/etc/sss/sss-client-$1.json"
SYSTEMD="/etc/systemd/system/sss-client-$1.service"
TARGET="/usr/local/bin/sss-client"

mkdir -p ~/sss-setup
cd ~/sss-setup

if [ -f ${TARGET} ] 
then
    echo "Found existing binary $TARGET."
else
    if ! [ -z ${SOCKS5_PROXY} ]; then
        CURL_PROXY="-x socks5h://${SOCKS5_PROXY}"
        echo "Downloading through ${SOCKS5_PROXY} ..."
    fi
    curl ${CURL_PROXY} -L https://github.com/sh4run/sss/releases/download/v1.01/sss-1.01-linux-x86-64.tar.gz -o sss.tar.gz
    if [ $? -ne 0 ]
    then
        echo "Not able to complete download!"
        exit 1;
    fi

    tar xzvf sss.tar.gz
    rm -f sss.tar.gz
    mv sss-local-* sss-client
    chmod +x sss-client
    mv -f sss-client $TARGET
fi

if [ -f ${CONF} ]; then
    echo "Found existing config ${CONF}"
else
    echo ${cfg_params[public_key]} | ssh-keygen -m pem -e -f /dev/stdin > sss-pub-key.pem
    mkdir -p /etc/sss/
    cp sss-pub-key.pem /etc/sss/sss-pub-key.$1.pem
    echo "Generating new config..."
    echo "{" >>${CONF}
    echo "    \"server\":[\"$1\"]," >>${CONF}
    echo "    \"server_port\":${cfg_params[server_port]}," >>${CONF}
    echo "    \"password\":\"${cfg_params[password]}\"," >>${CONF}
    echo "    \"method\":\"aes-128-gcm\"," >>${CONF}
    echo "    \"local_port\":${cfg_params[server_port]}," >>${CONF}
    echo "    \"local_address\":\"0.0.0.0\"," >>${CONF}
    echo "    \"public_key\":\"/etc/sss/sss-pub-key.$1.pem\"," >>${CONF}
    echo "    \"scramble_length\":${cfg_params[scramble_length]}" >>${CONF}
    echo "}" >>${CONF}

fi

if [ -f ${SYSTEMD} ]; then
    echo "Found existing service ${SYSTEMD}"
    systemctl daemon-reload
    systemctl restart sss-client-$1
else
    echo "Generating new service..."
    echo "[Unit]" >>${SYSTEMD}
    echo "Description=SSS($1)-client Service" >>${SYSTEMD}
    echo "After=network.target" >>${SYSTEMD}
    echo "" >>${SYSTEMD}
    echo "[Service]" >>${SYSTEMD}
    echo "Type=simple" >>${SYSTEMD}
    echo "LimitNOFILE=32768" >>${SYSTEMD}
    echo "ExecStart=$TARGET -c ${CONF}" >>${SYSTEMD}
    echo "" >>${SYSTEMD}
    echo "[Install]" >>${SYSTEMD}
    echo "WantedBy=multi-user.target" >>${SYSTEMD}

    systemctl daemon-reload
    systemctl enable sss-client-$1
    systemctl start sss-client-$1
fi

cd
rm -rf ~/sss-setup

