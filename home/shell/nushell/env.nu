

mkdir ~/.cache/starship
starship init nu | sed "s/size -c/size/" | save ~/.cache/starship/init.nu -f