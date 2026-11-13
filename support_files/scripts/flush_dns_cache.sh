#!/bin/zsh

# Clears the DNS cache and restarts mDNSResponder.

/usr/bin/dscacheutil -flushcache
/usr/bin/killall -HUP mDNSResponder

echo "DNS cache flushed"
