# Electronic Volumetric Display

This is a hand-held persistence-of-vision display built around the STM32WB55 microcontroller. It works by spinning a vertical RGB LED array fast enough to create three-dimensional images in space. The device will include a sensor suite for orientation sensing or viewer positioning and control.

The end goal is to have a custom slicer convert 3D models into LED frames that the STM32WB55 can display at the correct motor positions. Bluetooth will be used to control the display, while USB-C may be used for larger transfers and firmware development. The platform can display general volumetric graphics or operate as an electronic hourglass by linking its animations to a timer.

The Altium project uses shared symbols and footprints from the Altium Generic Components library. Clone that repository beside this project.
