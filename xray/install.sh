#!/bin/bash

# https://github.com/XTLS/Xray-install
# 安装并升级 Xray-core 和地理数据，使用 User=root，会覆盖已有服务文件中的 User 设置
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

# 仅更新 geoip.dat 和 geosite.dat
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata