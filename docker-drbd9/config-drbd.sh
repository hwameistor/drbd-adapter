#!/bin/bash

conf_file="/etc/drbd.conf"
example_file="/usr/share/doc/drbd.../drbd.conf.example"
content_to_append="include \"/etc/drbd.d/global_common.conf\";\ninclude \"/etc/drbd.d/*.res\";"
echo -e "# You can find an example in $example_file\n$content_to_append" > "$conf_file"
echo "Content successfully written to $conf_file."

conf_file2="/etc/drbd.d/global_common.conf"
content_to_write2="global { usage-count no; }"
mkdir -p "$(dirname "$conf_file2")"
echo "$content_to_write2" > "$conf_file2"
echo "Content successfully written to $conf_file2."
