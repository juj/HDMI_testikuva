HDMI testikuva
==============

This branch contains a minimal [GOWIN FPGA Designer](https://www.gowinsemi.com/en/support/home/) + Sipeed Tang Nano 9K FPGA implementation for HDMI ["testikuva"](https://fi.wikipedia.org/wiki/Testikuva) output in 640x480 resolution.

![testikuva](/images/testikuva.jpg "testikuva")

Testikuva is Finnish for "test picture", or "tuning picture". This specific picture, with identifier "Telefunken FuBK", was shown on Finnish national TV channels when there was no other broadcast on to help viewers tune their televisions, and was used up until the early 2000s.

What is this for?
-----------------

Nothing useful really, just a test project to learn about GOWIN's IDE and the Sipeed Tang Nano 9K board.

Changes compared to the 4K code
-------------------------------

* We must use the Gowin's rPLL module for the PLL instead of Gowin's PLLVR module.

* We must use Gowin's Emulated LVDS module instead of Gowin's True LVDS module due to the 9k pinout. See [Reddit thread](https://www.reddit.com/r/GowinFPGA/comments/z0df2o/where_are_the_lvdss_in_tang_nano_9k_board/) for more details.