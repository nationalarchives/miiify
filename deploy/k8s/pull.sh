#!/bin/bash

kubectl exec deploy/miiifyctl -- git -C /data/db pull origin master
