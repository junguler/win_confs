#!/bin/bash

aria2c -i c:/git/music-list.txt -d c:/git/bare_m3u/

sleep 5
echo "check if files are downloaded"
sleep 5
for f in c:/git/bare_m3u/*.m3u ; do mv "$f" "$(echo "$f" | sed -e 's/top_radio_//g')"; done
cat $( ls c:/git/bare_m3u/*.m3u -v ) | awk '!seen[$0]++' > c:/git/bare_m3u/---everything-full.m3u
cat c:/git/bare_m3u/---everything-full.m3u | sed -n '/^#/!p' > c:/git/bare_m3u/---everything-lite.m3u
cat c:/git/bare_m3u/---everything-lite.m3u | shuf > c:/git/bare_m3u/---randomized.m3u
cat c:/git/bare_m3u/---everything-lite.m3u | sort | awk 'length>10' > c:/git/bare_m3u/---sorted.m3u
mv c:/git/bare_m3u/*.m3u c:/git/m3u-radio-music-playlists/
git -C c:/git/m3u-radio-music-playlists/ add .
git -C c:/git/m3u-radio-music-playlists/ commit -m "updating"
git -C c:/git/m3u-radio-music-playlists/ push
