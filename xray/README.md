# 配置文件操作

# 生成 UUID (用于身份验证)
xray uuid

# 生成密钥对 (用于 Reality 加密) 
xray x25519

# 生成 ShortId
openssl rand -hex 8

# 进入资源目录
cd /usr/local/share/xray/

# 备份旧文件 (可选)
mv geoip.dat geoip.dat.bak
mv geosite.dat geosite.dat.bak

# 下载新的 geoip.dat
wget https://github.com/v2fly/geoip/releases/latest/download/geoip.dat -O geoip.dat

# 下载新的 geosite.dat
wget https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat -O geosite.dat

# test
# /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
# systemctl restart xray