# IPTables Snippets [Scratchpad]

Input-Drop-Policy

## SSH-Port vor Bots verstecken und mit Port-Knocking von außen öffnen:
``` sh
iptables --append   INPUT   --in-interface "${IF_WAN}"            \
         --protocol tcp     --dport        "${PORT_SSH_KNOCK_1}"  \
         --match    recent  --set          --name Knock1

iptables --append   INPUT   --in-interface "${IF_WAN}"            \
         --protocol tcp     --dport        "${PORT_SSH_KNOCK_2}"  \
         --match    recent  --rcheck       --name Knock1          \
         --match    recent  --set          --name Knock2

iptables --append   INPUT   --in-interface "${IF_WAN}"            \
         --protocol tcp     --dport        "${PORT_SSH}"          \
         --match    recent  --rcheck       --name Knock2          \
         --jump     ACCEPT
```
``` sh
nc  -w 1 -z -i 1 "${SERVER_IP}" "${PORT_SSH_KNOCK_1}" "${PORT_SSH_KNOCK_2}"  # client machine
ssh -p           "${PORT_SSH}"  "${SERVER_IP}"
```

## Protokollierung verworfener Pakete ermöglichen:
``` sh
# /var/log/iptables.log
# prefix is matched in /etc/rsyslog.conf and written to separate file, L4 = Warning
#
iptables --new-chain LOGDROP
iptables --append LOGDROP --match limit --limit 5/min --jump LOG 
         --log-level 4    --log-prefix "Iptables dropped "
iptables --append LOGDROP --jump DROP
```

## Rollen-basierte Ketten, separate Adressverwaltung:
``` sh
iptables --new-chain ADMINS
iptables --append ADMINS --source 10.100.0.1 --jump ACCEPT
iptables --append ADMINS --source 10.100.0.7 --jump ACCEPT
iptables --append ADMINS                     --jump LOGDROP
...
iptables --append INPUT --protocol tcp --match tcp --dport 22 --jump ADMINS
```

## Internet-Verkehr eines offenen WLAN durch TOR leiten/anonymisieren:
1. VPN-Verkehr wurde vorher akzeptiert
2. Trusted User nicht arglos/versehentl. in TOR bzw. [feindliche Exit-Nodes](http://archive.wired.com/politics/security/news/2007/09/embassy_hacks?currentPage=all) laufen lassen, soll VPN nutzen:
``` sh
iptables --new-chain BLOCKTOR
iptables --append INPUT   --in-interface "${IF_LAN_UNTRUST}" --jump BLOCKTOR
iptables --append FORWARD --in-interface "${IF_LAN_UNTRUST}" --jump BLOCKTOR

for trusted_mac in "${TRUSTED_MACS}"
do
    iptables --append BLOCKTOR  \
             --match  mac       --mac-source   "${trusted_mac}"     \
             --jump   REJECT    --reject-with  icmp-net-prohibited  \
             --match  comment   --comment      "Friends better use VPN"
done
```
```
iptables --append   INPUT       --in-interface "${IF_LAN_UNTRUST}"  \ 
         --protocol tcp         --dport        "${PORT_TOR_DNS}"    \
         --jump     ACCEPT

iptables --append   INPUT       --in-interface "${IF_LAN_UNTRUST}"  \ 
         --protocol udp         --dport        "${PORT_TOR_DNS}"    \   
         --jump     ACCEPT

iptables --append   INPUT       --in-interface "${IF_LAN_UNTRUST}"  \
         --protocol tcp         --dport        "${PORT_TOR_TRANS}"  \
         --jump     ACCEPT

iptables --table    nat                                             \
         --append   PREROUTING  --in-interface "${IF_LAN_UNTRUST}"  \
         --protocol udp         --dport        53                   \
         --jump     REDIRECT    --to-ports     "${PORT_TOR_DNS}"    \
         --match    comment     --comment      "TOR DNS redirect"

iptables --table    nat                                             \
         --append   PREROUTING  --in-interface "${IF_LAN_UNTRUST}"  \
         --protocol tcp         --syn                               \
         --jump     REDIRECT    --to-ports     "${PORT_TOR_TRANS}"  \
         --match    comment     --comment      "TOR redirect"
```

