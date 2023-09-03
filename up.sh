#!/bin/sh
#copyright by hiboy and gustavo8000br
#One-click automatic firmware update script
#wget --no-check-certificate -O- https://opt.computandotech.com.br/opt-script/up.sh | sed -e "s|^\(Firmware.*\)=[^=]*$|\1=|" > /tmp/up.sh && bash < /tmp/up.sh
logger_echo () {
    logger -t "【Firmware】" "$1"
    echo "$(date "+%Y-%m-%d_%H-%M-%S") ""$1"
}
if [ -f /tmp/up_Firmware ] ; then
    logger_echo "The last update was incomplete, skip the update! Wait a few minutes to try updating again!"
    exit
fi
touch /tmp/up_Firmware
[ -f ~/.wget-hsts ] && chmod 644 ~/.wget-hsts
export LD_LIBRARY_PATH=/lib:/opt/lib
Firmware="$1"
mkdir -p /tmp/padavan
rm -f /tmp/padavan/*
# Firmware update judgment
[ ! -f /tmp/ver_time ] && echo -n "0" > /tmp/ver_time
if [ $(($(date "+1%m%d%H%M") - $(cat /tmp/ver_time))) -gt 1 ] ; then
echo -n `nvram get firmver_sub` > /tmp/padavan/ver_osub
rm -f /tmp/padavan/ver_nsub
wget  -O /tmp/padavan/ver_nsub https://opt.computandotech.com.br/opt-file/osub
if [ ! -s /tmp/padavan/ver_nsub ] ; then
rm -f /tmp/padavan/ver_nsub
wget --no-check-certificate  -O /tmp/padavan/ver_nsub https://opt.computandotech.com.br/opt-file/osub
fi
if [ -s /tmp/padavan/ver_osub ] && [ -s /tmp/padavan/ver_nsub ] && [ "$(cat /tmp/padavan/ver_osub |head -n1)"x == "$(cat /tmp/padavan/ver_nsub |head -n1)"x ] ; then
    logger_echo "New firmware：$(cat /tmp/padavan/ver_nsub | grep -v "^$")"
    logger_echo "Current firmware：$(cat /tmp/padavan/ver_osub | grep -v "^$") "
    logger_echo "No update! If you need to flash in again, please run this command again within one minute to force the update"
    echo -n "$(date "+1%m%d%H%M")" > /tmp/ver_time
    echo "$(date "+1%m%d%H%M")"
    rm -f /tmp/up_Firmware; rm -f /tmp/padavan/* ;
    logger_echo "Update script"
    sh_upscript.sh upscript
    exit;
else
    echo -n `nvram get firmver_sub` > /tmp/padavan/ver_osub
    logger_echo "New firmware：$(cat /tmp/padavan/ver_nsub | grep -v "^$") ，Current old firmware： $(cat /tmp/padavan/ver_osub | grep -v "^$") "
    logger_echo "Update firmware：$(cat /tmp/padavan/ver_nsub | grep -v "^$") "
fi
else
    logger_echo "Make a forced update"
fi
# Firmware MD5 judgment
wget  -O /tmp/padavan/MD5.txt https://opt.computandotech.com.br/padavan/MD5.txt
if [ ! -s /tmp/padavan/MD5.txt ] ; then
rm -f /tmp/padavan/MD5.txt
wget --no-check-certificate  -O /tmp/padavan/MD5.txt https://opt.computandotech.com.br/padavan/MD5.txt
fi
dos2unix /tmp/padavan/MD5.txt
sed -e 's@\r@@g' -i /tmp/padavan/MD5.txt
if [ "$Firmware"x != "x" ] ; then
MD5_txt=`cat /tmp/padavan/MD5.txt | sed 's@\r@@g' |sed -n '/'$Firmware'/,/CRC32/{/'$Firmware'/n;/CRC32/b;p}' | grep "MD5：" | tr 'A-Z' 'a-z' |awk '{print $2}'`
if [ "$MD5_txt"x = x ] ; then
    logger_echo " Failed to obtain【 $Firmware 】"
    Firmware=""
fi
fi
if [ "$Firmware"x = "x" ] ; then
PN=`grep Web_Title= /www/EN.dict | sed 's@\r@@g' | sed 's/Web_Title=//g'| sed 's/ Wireless Router\| Wireless Router//g'`
[ "$PN"x != "x" ] && Firmware=`cat /tmp/padavan/MD5.txt | sed 's@\r@@g' | grep -Eo "$PN"'_.*' | sed -n '1p'`
fi
if [ "$Firmware"x = x ] ; then
    logger_echo " Failed to get 【$Firmware】model, skip update! Try manually specifying the model update! /tmp/up.sh "$Firmware"_3.4.3.9-099.trx &"
    rm -f /tmp/up_Firmware; rm -f /tmp/padavan/* ; exit;
fi
MD5_txt=`cat /tmp/padavan/MD5.txt | sed 's@\r@@g' |sed -n '/'$Firmware'/,/CRC32/{/'$Firmware'/n;/CRC32/b;p}' | grep "MD5：" | tr 'A-Z' 'a-z' |awk '{print $2}'`
if [ "$MD5_txt"x = x ] ; then
    logger_echo " Failed to get【 $Firmware 】model https://opt.computandotech.com.br/padavan/MD5.txt For the record, skip the update! You can try updating again later！"
    rm -f /tmp/up_Firmware; rm -f /tmp/padavan/* ; exit;
fi
# Adjust /tmp free space
size_tmpfs=`nvram get size_tmpfs`
[ -z "$size_tmpfs" ] && size_tmpfs="0"
[ "$size_tmpfs" = "0" ] && mount -o remount,size=80% tmpfs /tmp
rm -rf /tmp/xupnpd-cache
rm -rf /tmp/xupnpd-feeds
sync;echo 1 > /proc/sys/vm/drop_caches
logger_echo " Download【 $Firmware 】， https://opt.computandotech.com.br/padavan/$Firmware"
wget  -O "/tmp/padavan/$Firmware" "https://opt.computandotech.com.br/padavan/$Firmware"
if [ ! -s "/tmp/padavan/$Firmware" ] ; then
rm -f "/tmp/padavan/$Firmware"
wget --no-check-certificate  -O "/tmp/padavan/$Firmware" "https://opt.computandotech.com.br/padavan/$Firmware"
fi
eval $(md5sum /tmp/padavan/$Firmware | awk '{print "MD5_down="$1;}')
echo "$MD5_down"
echo "$MD5_txt"
# Firmware flashing
if [ -s "/tmp/padavan/$Firmware" ] && [ "$MD5_txt"x = "$MD5_down"x ] ; then
    logger_echo " Finish downloading 【$Firmware】, md5 match, start updating! Please do not turn off the power!"
    rm -f /tmp/padavan/log.txt
    mtd_write -r write "/tmp/padavan/$Firmware" Firmware_Stub  > /tmp/padavan/log.txt  2>&1 &
    sleep 1
    while [ ! -f /tmp/padavan/log.txt ] ; do
        sleep 10
        logger_echo " Wait【$Firmware】Please do not power off!"
    done
    while [ -s /tmp/padavan/log.txt ] && [ ! -z "`pidof mtd_write`" ] ; do
        logger_echo " Wait a moment【$Firmware】is being updated! Please do not turn off the power!"
        sleep 10
    done
    mtd_log=`cat /tmp/padavan/log.txt | grep -Eo '\[ok\]'`
    if [ -s /tmp/padavan/log.txt ] && [ "$mtd_log"x = '[ok]x' ] ; then
        logger_echo " Update 【$Firmware】, [ok]!"
        logger_echo " Wait for 【$Firmware】, it will restart automatically!"
        logger_echo " Appear [ok]! For successful flashing, automatically restart the router"
        sleep 2
        mtd_write -r unlock mtd1
        sleep 10
        reboot
        sleep 10
        mtd_write -r unlock mtd1
        sleep 10
        reboot
        logger_echo "If the automatic restart fails, try to manually restart the router"
    else
        logger_echo "`cat /tmp/padavan/log.txt`"
        logger_echo " Flashing error 【$Firmware】, update failed!"
    fi
else
    logger_echo " Download 【$Firmware】, the md5 is different from the record, the download failed, skip the update! You can try to update again after restarting!"
    logger_echo " Download md5: $MD5_down"
    logger_echo " Record md5: $MD5_txt"
fi
rm -f /tmp/up_Firmware; rm -f /tmp/padavan/* ; exit;

