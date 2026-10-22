#!/bin/sh

# This script will check the status of the SentinelOne Agent

# Jamf runs inventory from a LaunchDaemon whose default PATH doesn't include /usr/local/bin, where sentinelctl is installed
PATH="/usr/local/bin:$PATH"

if command -v sentinelctl 1>/dev/null; then
        echo "<result> SentinelOne agent is installed with version `sentinelctl version | awk '{print $2}'` and was connected to management console `sentinelctl config Server Address | tail -1 | awk '{print $2}'` </result>"
else
        s1_agent=$(ps aux | grep -Ei "sentineld$" | awk '{ print $11 };' | grep -v grep)
                if [ -z $s1_agent ]; then
                       echo "<result>SentinelOne Agent is not Installed.</result>";
                else
                       s1_agent=$(echo $s1_agent | sed 's|sentineld|sentinelctl|g')
                        echo "<result>SentinelOne Agent is running but could not locate SentinelCtl in the default PATH /usr/local/bin. The full path is - $s1_agent </result>" ;
                fi
fi
