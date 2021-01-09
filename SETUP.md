# Setup wifi

```bash
$ iwctl device list
$ iwctl --passphrase ${password} station ${device_name} connect ${ssid}
```

# Download installation-scripts
```bash
pacman -Sy git
```