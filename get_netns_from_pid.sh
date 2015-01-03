#!/bin/bash

if [ $# -ne 1 ]; then
  echo "USAGE: pid"
  exit 1
fi

pid=$1

if [ ! -d "/proc/${pid}/" ]; then
  echo "no such of pid ${pid}"
  exit 2
fi

if [ -f "/var/run/netns/${pid}" ]; then
  echo "PID ${pid}'s network namespace already exposed to iproute"
  exit 3
fi

ln -s /proc/${pid}/ns/net /var/run/netns/${pid}
echo "linkded to /proc/${pid}/ns/net /var/run/netns/${pid}"



