#!/bin/bash

# Bash function to check for crontab entry, if not, decode disk usage script and add to crontab
install_script() {
  crontab -l | grep "disk-usage.sh" > /dev/null
  if [ $? -eq 1 ]; then
    echo "Adding cronjob"
    mkdir -p '/root/jobs/system'
    echo "IyEvYmluL2Jhc2gKCiMgQXJyYXkgb2YgcGFydGl0aW9ucyB0byBjaGVjawpmaWxlc3lzdGVtcz0o
Ii8iKQoKIyBQdXNob3ZlciB0b2tlbnMKX3Rva2VuPSIiCl91c2VyPScnCgojIEJhc2ggZnVuY3Rp
b24gdG8gcHVzaCBub3RpZmljYXRpb24gdG8gcmVnaXN0ZXJlZCBkZXZpY2UKcHVzaG92ZXIoKXsK
ICBsb2NhbCB0PSIkezE6Y2xpLWFwcH0iCiAgbG9jYWwgbT0iJDIiCiAgW1sgIiRtIiAhPSAiIiBd
XSAmJgogIGN1cmwgLXMgXAogIC0tZm9ybS1zdHJpbmcgInRva2VuPSR7X3Rva2VufSIgXAogIC0t
Zm9ybS1zdHJpbmcgInVzZXI9JHtfdXNlcn0iIFwKICAtLWZvcm0tc3RyaW5nICJ0aXRsZT0kdCIg
XAogIC0tZm9ybS1zdHJpbmcgIm1lc3NhZ2U9JG0iIFwKICBodHRwczovL2FwaS5wdXNob3Zlci5u
ZXQvMS9tZXNzYWdlcy5qc29uCn0KCiMgTG9vcCB0aHJvdWdoIGVhY2ggcGFydGl0aW9uIGFuZCBz
ZW5kIHB1c2hvdmVyIGFsZXJ0IGlmIHV0aWxpemF0aW9uIGlzIGdyZWF0ZXIgdGhhbiA5MCUuCmZv
ciBpIGluICR7ZmlsZXN5c3RlbXNbQF19OyBkbwogIHVzYWdlPSQoZGYgLWggJGkgfCB0YWlsIC1u
IDEgfCBhd2sgJ3twcmludCAkNX0nIHwgY3V0IC1kICUgLWYxKQogIGlmIFsgJHVzYWdlIC1nZSA5
MCBdOyB0aGVuCiAgICBhbGVydD0iUnVubmluZyBvdXQgb2Ygc3BhY2Ugb24gJGkuIFVzYWdlIGlz
OiAkdXNhZ2UlIgogICAgZWNobyAiU2VuZGluZyBvdXQgYSBkaXNrIHNwYWNlIGFsZXJ0IGVtYWls
LiIKICAgIGVjaG8gJGFsZXJ0CiAgICBwdXNob3ZlciAiJGkgb24gJChob3N0bmFtZSAtcykgaXMg
JHVzYWdlJSBmdWxsIiAiJHthbGVydH0iCiAgZmkKZG9uZQoK" | base64 -d > '/root/jobs/system/disk-usage.sh'
    (crontab -l 2>/dev/null; echo -e '# Disk utilization check\n00 */6 * * * /root/jobs/system/disk-usage.sh') | crontab -
    rm $0
  else
    echo "cronjob already exists"
  fi
}

install_script
