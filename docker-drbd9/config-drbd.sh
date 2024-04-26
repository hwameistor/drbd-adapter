#!/bin/bash

conf_file="/etc/drbd.conf"
example_file="/usr/share/doc/drbd.../drbd.conf.example"
content_to_append="include \"/etc/drbd.d/global_common.conf\";\ninclude \"/etc/drbd.d/*.res\";"
if [ ! -s "$conf_file" ]; then
    echo -e "# You can find an example in $example_file\n$content_to_append" > "$conf_file"
    echo "Content successfully written to $conf_file."
else
    echo "$conf_file exists and is not empty."
fi


conf_file2="/etc/drbd.d/global_common.conf"
content_to_write2="global { usage-count no; }"

if [ ! -s "$conf_file2" ]; then
    mkdir -p "$(dirname "$conf_file2")"
    echo "$content_to_write2" > "$conf_file2"
    echo "Content successfully written to $conf_file2."
else
    echo "$conf_file2 exists and is not empty."
fi
