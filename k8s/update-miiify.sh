#!/bin/bash

result=$(./pull.sh | (tail -n 1))

if [ "$result" = "Already up to date." ]; then
    echo "No new annotations to pull"
else
    ./restart.sh
fi
