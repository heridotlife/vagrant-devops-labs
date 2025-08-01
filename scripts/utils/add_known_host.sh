#!/bin/bash

for ip in 192.168.56.11 192.168.56.12 192.168.56.13 192.168.56.21 192.168.56.22; do
  ssh-keyscan -H $ip >> ~/.ssh/known_hosts
done

