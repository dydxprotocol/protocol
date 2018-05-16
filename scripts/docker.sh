#!/bin/bash

cleanup ()
{
  kill -s SIGTERM $!
  exit 0
}

trap cleanup SIGINT SIGTERM

npm run node -- -i -d 1212 -p 8545 -h 127.0.0.1 &
sleep 5
npm run migrate -- --network=docker

while [ 1 ]
do
  sleep 60 &
  wait $!
done
