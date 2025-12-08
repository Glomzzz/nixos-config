sudo mkdir -p /run/systemd/system/nix-daemon.service.d/
sudo tee /run/systemd/system/nix-daemon.service.d/override.conf << EOF
[Service]
Environment="https_proxy=socks5h://localhost:20171"
EOF
sudo systemctl daemon-reload
sudo systemctl restart nix-daemon
