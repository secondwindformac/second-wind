# FaceTime HD camera

2013-2017 MacBooks use a camera (Broadcom 1570) that Linux does not support
out of the box. Second Wind installs the community
[facetimehd](https://github.com/patjak/facetimehd) driver through DKMS (it
rebuilds itself with every new kernel) and extracts the camera firmware
**locally** from an official Apple package (the firmware belongs to Apple and
cannot be redistributed; that is why it is extracted on your machine).

## If the installer said the camera could not be enabled

1. Nothing is broken: the installer rolled back everything camera-related and
   the rest of Second Wind keeps working.
2. Typical causes: the kernel is newer than the driver supports, or the
   firmware package could not be downloaded.
3. Retry after updating the system:

   ```bash
   ./install.sh --only hardware
   ```

## Checking whether it works

```bash
ls /dev/video0
```

If it exists, open Ubuntu's "Camera" app (or any video call). If the driver
installed but `/dev/video0` is missing, reboot the computer.
