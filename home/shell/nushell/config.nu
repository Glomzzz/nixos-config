$env.config.show_banner = false
$env.config.filesize.metric = true

# 遍历 `completions` 文件夹中的每个子文件夹
ls completions |
each { |dir|
    # 获取子文件夹的名称（命令名）
    let cmd = $dir.name
    # 检查命令是否可以被执行
    if (which $cmd) {
        # 如果命令可以执行，则加载对应的 completions 文件
        let completion_path = $"completions/($cmd)/($cmd)-completions.nu"
        open temp_script.nu | append $"use $completion_path *" | save temp_script.nu
        print $"Loaded completions for ($cmd)"
    } else {
        print $"Command ($cmd) is not installed"
    }
}

source ./temp_script.nu
