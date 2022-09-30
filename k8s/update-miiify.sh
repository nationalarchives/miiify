#!/bin/bash

result=$($HOME/git/miiify/k8s/pull.sh | (tail -n 1))

if [ "$result" = "Already up to date." ]; then
    echo "No new annotations to pull"
else
    $HOME/git/miiify/k8s/restart.sh
fi
