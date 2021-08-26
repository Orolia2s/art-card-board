# ART_CARD FIRMWARE
Generation of the ART_CARD firmware. It's based on the **10CX105YF672I5G** device.

Configuration device is **MT25QU256**.

## Needed tools
Quartus Prime Pro Edition release v21.1 or later available here : https://fpgasoftware.intel.com/?edition=pro

Don't need to have a licence for compilation of Cyclone 10 GX.

USB Blaster II Download Cable.

## Build of the Firmware
Load the design with the Quartus Prime Pro and launch compilation.

Use the **create_jic_dual.cof** configuration file to convert output .SOF file into a .JIC file including factory and user image.

Use the **create_pof_rpd_dual.cof** configuration file to convert output .sof file into a.bin file including factory and user image. The output file **art_card_auto.rpd** must be split in half, higher part is the upgrade binary files.
 
## Program the board
Use the JTAG dongle and the .JIC file to program the board the first time.

Futur update can be done over the software using the binary update file.
