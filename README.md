# art-card-board
Project hosting schematics production files and firmware

## Update ART Card firmware with devlink

Firmware can be updated using devlink if card is exposed on a host server using [ptp_ocp driver](https://github.com/opencomputeproject/Time-Appliance-Project/tree/master/Time-Card/DRV).

For example, if PCI card is located on **0000:03:00.0** on the server:

```
> sudo cp art_card_vX_update.bin /lib/firmware
> sudo devlink dev flash pci/0000:03:00.0 file art_card_vX_update.bin
```

Then a power cycle is mandatory for the firmware update to complete.
Starting from **Rev3** of the card a reboot is sufficient for update to complete.

You may then see in the kernel messages the new firmware version displayed:

```
> sudo dmesg -w
/ ** /
[  517.689840] ptp_ocp 0000:03:00.0: Version 0.0.X, clock NONE, device ptp2
/ ** /
```

## Update ART Card firmware through USB

Starting from Revision 4 of the board, the card has a USB-C port with an FTDI on it. This FTDI is configured to R/W the flash of the card.
To update the card using the USB interface, one will need to install [flashrom](https://github.com/flashrom/flashrom) with **libftdi** already installed.
Connect the USB cable to the computer that has flashrom installed then install.
Use flashrom to flash the .rpd file on the card:

```
sudo ./flashrom -p ft2232_spi:type=4233H -c MT25QU256 -w <PATH to .rpd file>
```
