#!/usr/bin/expect -f

set install_cmd "apt install -y /root/drbd.deb"

set timeout 600

spawn sh -c $install_cmd
expect {
    "Configuration file '/etc/drbd.conf'" {
        send "Y\r"
        exp_continue
    }
    timeout {
        # 处理超时情况的操作，或者留空以忽略超时
    }
    eof {
        # 安装命令结束后的处理逻辑
    }
}
