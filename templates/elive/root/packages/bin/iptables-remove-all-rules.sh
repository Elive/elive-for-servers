#!/bin/bash
#source /usr/lib/elive-tools/functions
PATH="$PATH:/usr/sbin"

if [[ "${UID}" != "0" ]] ; then
    echo -e "Must be root"
    exit 1
fi

## flush all chains
#iptables -F
#iptables -t nat -F
#iptables -t mangle -F
## delete all chains
#iptables -X


iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X

ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -t nat -F
ip6tables -t mangle -F
ip6tables -F
ip6tables -X

echo done
