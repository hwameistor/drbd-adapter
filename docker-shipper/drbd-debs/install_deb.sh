#!/usr/bin/expect -f

set install_cmd1 "apt install -y /root/drbd_utils.deb"
set install_cmd2 "apt install -y /root/drbd.deb"

set timeout 600

spawn sh -c $install_cmd1
expect {
    "\"*** drbd.conf (Y/I/N/O/D/Z) \[default=N\] ?\"" {
        send "Y\r"
        exp_continue
    }
    timeout {
        # 处理超时情况的操作，或者留空以忽略超时
    }
    eof {
        # 第一个安装命令结束后的处理逻辑
        spawn sh -c $install_cmd2
        expect {
            "\"*** drbd.conf (Y/I/N/O/D/Z) \[default=N\] ?\"" {
                send "Y\r"
                exp_continue
            }
            timeout {
                # 处理超时情况的操作，或者留空以忽略超时
            }
            eof {
                # 第二个安装命令结束后的处理逻辑
            }
        }
    }
}
