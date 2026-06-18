sudo mkdir -p /run/systemd/system/nix-daemon.service.d/
sudo tee /run/systemd/system/nix-daemon.service.d/override.conf << EOF
[Service]
Environment="http_proxy=http://127.0.0.1:20172"
Environment="https_proxy=http://127.0.0.1:20172"
Environment="all_proxy=socks5h://127.0.0.1:20170"
Environment="no_proxy=127.0.0.1,localhost,::1"
EOF
sudo systemctl daemon-reload
sudo systemctl restart nix-daemon
