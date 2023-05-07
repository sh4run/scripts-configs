##!/bin/bash 
#
# Usage: 
#      sudo ./sss-server.sh <port-num>
#

if ! [ "$1" -eq "$1" ] 2>/dev/null
then
   echo "Usage:"
   echo "    sudo ./sss-server.sh <port-num>"
   exit
fi

if [ "$(id -u)" -ne 0 ]; then
   echo "Usage:"
   echo "    sudo ./sss-server.sh $1"
   exit
fi

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

CONF="/etc/sss/sss-server.json"
SYSTEMD="/etc/systemd/system/sss-server.service"

mkdir -p ~/sss-setup
cd ~/sss-setup

wget --no-check-certificate -O sss.tar.gz https://github.com/sh4run/sss/releases/download/v1.01/sss-1.01-linux-x86-64.tar.gz
tar xzvf sss.tar.gz
rm -f sss.tar.gz
mv sss-server-* sss-server
chmod +x sss-server
mv -f sss-server /usr/local/bin/

if [ -f ${CONF} ]; then
    echo "Found existing config ${CONF}"
else
    PSK=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    RNUM=$(date +%N)
    RNUM=${RNUM#0}
    SCRAMB=$(( $RNUM % 300 +20 ))

    ssh-keygen -b 1024 -m pem -f sss-key -N "" -q
    #ssh-keygen -m pem -e -f sss-key >sss-key_pub.pem

    mkdir /etc/sss/
    cp sss-key /etc/sss
    echo "Generating new config..."
    echo "{" >>${CONF}
    echo "    \"server\":[\"0.0.0.0\"]," >>${CONF}
    echo "    \"server_port\":$1," >>${CONF}
    echo "    \"password\":\"$PSK\"," >>${CONF}
    echo "    \"method\":\"aes-128-gcm\"," >>${CONF}
    echo "    \"private_key\":\"/etc/sss/sss-key\"," >>${CONF}
    echo "    \"scramble_length\":$SCRAMB" >>${CONF}
    echo "}" >>${CONF}

    client_cfg=$(echo "{")
    client_cfg="$client_cfg"$(echo "\"server_port\":$1,")
    client_cfg="$client_cfg"$(echo "\"password\":\"$PSK\",")
    client_cfg="$client_cfg"$(echo "\"scramble_length\":$SCRAMB,")
    client_cfg="$client_cfg"$(echo "\"public_key\":\"")
    client_cfg="$client_cfg"$(cat sss-key.pub)
    client_cfg="$client_cfg"$(echo "\"}")
    
    client_cfg=$(echo $client_cfg | base64 -w0)
    echo "\n\n"
    echo "***Client config string***"
    echo $client_cfg 
    echo "\n\n"
fi

if [ -f ${SYSTEMD} ]; then
    echo "Found existing service ${SYSTEMD}"
    systemctl daemon-reload
    systemctl restart sss-server
else
    echo "Generating new service..."
    echo "[Unit]" >>${SYSTEMD}
    echo "Description=SSS-server Service" >>${SYSTEMD}
    echo "After=network.target" >>${SYSTEMD}
    echo "" >>${SYSTEMD}
    echo "[Service]" >>${SYSTEMD}
    echo "Type=simple" >>${SYSTEMD}
    echo "LimitNOFILE=32768" >>${SYSTEMD}
    echo "ExecStart=/usr/local/bin/sss-server -c ${CONF}" >>${SYSTEMD}
    echo "" >>${SYSTEMD}
    echo "[Install]" >>${SYSTEMD}
    echo "WantedBy=multi-user.target" >>${SYSTEMD}

    systemctl daemon-reload
    systemctl enable sss-server
    systemctl start sss-server
fi

rm -rf ~/sss-setup

