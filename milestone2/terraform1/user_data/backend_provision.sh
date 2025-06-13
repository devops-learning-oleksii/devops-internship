#!/bin/bash

sudo apt update
sudo apt install -y python3 python3-pip postgresql-client

pip3 install "boto3>=1.28.0" "botocore>=1.31.0"