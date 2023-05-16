Table of Contents
- [SSH tunnel over SSS](https://github.com/sh4run/scripts-configs#ssh-tunnel-over-sss)
- [SSS Installation](https://github.com/sh4run/scripts-configs#sssscrambled-shadowsocks-installation)

***
# SSH tunnel over SSS
*Below content is suitable for any proxy protocol that supports socks5 interface.*

Tests show GFW is likely sensitive to TCP connection establishment. A normal proxy, which handles each request(SOCKS5) separately in different TCP connections, can trigger more GFW inspections & receive more GFW probes. While a proxy working in tunnel mode receives much less probes. 

Say your sss-client listens on port 9080 (local socks5), and other than sss-server, ss or snell server is installed and listens on port 10080 on your remote vps, below command establishes a ssh tunnel from your local-machine:9081 to remote-vps:10080.

    ssh -N -L 0.0.0.0:9081:127.0.0.1:10080 -o ProxyCommand='nc -X 5 -x 127.0.0.1:9080 %h %p' 127.0.0.1
    
Now you can configure your ss or snell client to local-machine:9081. 

An unencrypted tunnel can be established with ncat:

    ncat -k -l -p 9081 -c "ncat --proxy 127.0.0.1:9080 --proxy-type socks5 127.0.0.1 10080"

As the traffic is encrypted by the underlying SSS anyway, it doesn't really matter whether the tunnel is encrypted or not. It is interesting in my test, ssh tunnel shows a better performance than ncat tunnel, even with one more encryption/decryption.  

Now most connections on your remote vps are from 127.0.0.1 and there is only one foreign connection from your local-machine (command: netstat -pnt). This behavior is different from "proxy-relay" or "tunnel" in clash. In those two cases, you will still observe multiple connections from your local machine.    

SOCKS5 is not recommended here as there is a greeting handshake in socks5 protocol. When a socks5 server is deployed on your vps, this handshake takes place on WAN. This makes socks5 inefficient in connection setup. In protocols like snell/ss, this handshake process is omitted on the WAN side. 

***

# SSS(Scrambled Shadowsocks) Installation
There are two components: sss-server and sss-client. sss-server is installed on your vps while sss-client is installed on another linux machine inside GFW, better in your home. sss-client provides a socks5 interface to any actual end devices. Please refer to [Scrambled Shadowsocks](https://github.com/sh4run/sss#sss---scrambled-shadowsocks) for a detailed description of the protocol. 

Both sss-server and sss-client rely on glibc 2.34. At this moment only **ubuntu 22.04** can provide this support.

Though normally it requires 1G memory, Ubuntu 22.04 is still possible to be installed on a small VPS with 512M memory. But **DO NOT** upgrade to the latest. 

## SSS-Server

These commands are executed on your vps. 

    wget https://raw.githubusercontent.com/sh4run/scripts-configs/main/sss-server.sh 
    chmod +x sss-server.sh
    sudo ./sss-server.sh <port-number>

There will be something like below displayed on the screen. You will need that string later when installing sss-client. 

    Generating new config...


    ***Client config string***
    yJzZeyJzZXJ2ZXJfcG9ydCI6MTIzNDUsInBhc3N3b3JkIjoiQVc1Q2lqbmZrSW9rMUU3USIsInNjcmFtYmxlX2xlbmd0aCI6MjQzLCJwdWJsaWNfa2V5Ijoic3NoLXJzYSBBQUFBQjNOemFDMXljMkVBQUFBREFRQUJBQUFBZ1FEQkNiTU1sNyt5Uk9Xc0hBMldlbXdreWlHSkVkWlNFMFFnNmlRdUwzWUJLalVjY2d6bFJNd1BUc09KNVdUcy92S1hLQkt2Z2x4SXQrSU5SYlNzN25RbnA5VHNYNlFBQmFIUU1wOHQ0STdTanlQd1lkL0JQRXhPaXEwTXY2ZUxSYlA2QXZDeExPYVBkc0JSZWYzOExTMEh4b2RQTHBpeDJtSTY4clduN0Era1h3PT0gcm9vdEBsb2NhbGhvc3QifQo=

You can use this command to check the status:

    sudo systemtl status sss-server
    
## SSS-Client
Download the script:

    wget https://raw.githubusercontent.com/sh4run/scripts-configs/main/sss-client.sh 
    
If you have access problem and you already have a socks5 proxy, you can use the alternative below:

    curl -x socks5h://127.0.0.1:1080 https://raw.githubusercontent.com/sh4run/scripts-configs/main/sss-client.sh -o sss-client.sh
    
Make the script executable:

    chmod +x sss-client.sh

Please don't forget the keyword **bash** in the command.

    sudo bash ./sss-client.sh <server-ip> <client-config-string>

If you already have a socks5 proxy, you can try below: 
   
    sudo bash -c 'export SOCKS5_PROXY=127.0.0.1:1080; ./sss-client.sh <server-ip> <client-config-string>'

Please use this command to check the status:
    
    systemctl status 'sss-client*'

The service name is something like "sss-client-xx.xx.xx.xx.service". "xx.xx.xx.xx" is the server ip that client connects to. If you have multiple sss-servers, you can use this script to install multiple sss-clients on the same machine.

By default, sss-client provides socks5 service on the same port number specified when installing sss-server. You can edit "local_port" in the config file "/etc/sss/sss-client-xx.xx.xx.xx.json" to change it.  Please restart sss-client to make the change take effect.

    sudo systemctl restart sss-client-xx.xx.xx.xx

## UDP Relay
SSS inherits the entire UDP relay function from shadowsocks-libev unchanged. Both sss-server and sss-client work in TCP-only mode by default. To enable UDP relay, simply put this line into both /etc/sss/sss-server.json & /etc/sss/sss-client-xx.xx.xx.xx.json and restart the services.

    {
       ...
       "mode":"tcp_and_udp",
       ...
    }
    
## Uninstall
You can use "sss-uninstall.sh" to remove any SSS component. If multiple sss-clients are installed, all are removed. 

    wget https://raw.githubusercontent.com/sh4run/scripts-configs/main/sss-uninstall.sh 
    chmod +x sss-uninstall.sh
    sudo bash ./sss-uninstall.sh
    

