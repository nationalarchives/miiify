#!/bin/bash

case $1 in
  "git"|"pack")
    cp ../lib/db.$1.ml ../lib/db.ml
    docker compose up $1 --build -d
    rspec integration.rb -fd
    docker compose down $1;;
  *) echo "supported backends: pack | git";;
esac