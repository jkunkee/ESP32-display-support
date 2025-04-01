
# Using Tasmota on the Waveshare ESP32-S3-LCD-1.69

The Waveshare ESP32-S3-LCD-1.69 dev board is an ESP32-S3R8-based development board. Per [its product page and docs](https://www.waveshare.com/ESP32-S3-LCD-1.69.htm), it sports a wide array of peripherals:

* QMI8658 IMU
* PCF85063 RTC
* ST7789V2-driven 240x280 rounded-corner LCD screen
* lithium-ion battery charger
* 16MiB (128Mib) SPI flash
* 12-pin breakout header (breakout-to-100-mil/Dupont cable provided)
* 3.3V regulator

This document aims to help the savvy user use as many of these peripherals as possible under [Tasmota](https://tasmota.github.io/docs/), with the caveat that a more expert Tasmota user may know how to do it more easily. (For example, one of the stock ESP32-S3 images may support everything needed, obviating the need for a custom build of Tasmota, and much of the work detailed here can probably be done in a pre-made board config.)

The dev board comes in two versions, the V1 and the V2, with V2 sporting some I/O rework described in [the product wiki](https://www.waveshare.com/wiki/ESP32-S3-LCD-1.69#09_LVGL_Keys_Bee). Most notably, V1 had some pins attached to peripherals that were also required to use the "R8" in-package octal SPI PSRAM that the V2 moved to less conflicted pins.

It also has a very similar touchscreen variant, [the ESP32-S3-Touch-LCD-1.69](https://www.waveshare.com/ESP32-S3-Touch-LCD-1.69.htm), that this document does not cover. That said, it is likely that the only difference will be adding a touch configuration section to the [LCD configuration in `display.ini`](https://tasmota.github.io/docs/Universal-Display-Driver/#descriptor-file); [Tasmota even has an example](https://github.com/arendst/Tasmota/blob/development/tasmota/displaydesc/ST7789_display.ini), though it may need significant rework.

## Custom Tasmota Build

Please follow [Tasmota's docs for building and installing a custom version of Tasmota](https://tasmota.github.io/docs/Compile-your-build/) with the changes described in this section.

### `platform_override.ini`

Follow the Tasmota instructions to copy `platform_override_sample.ini`, then:

* Change `default_envs` to `tasmota32s3`.
    * With a V2 board or with [a V1 with the buzzer diconnected](https://github.com/waveshareteam/ESP32-display-support/issues/7), using `tasmota32s3-qio_opi-all` instead will enable the in-package PSRAM.
    * If enabling PSRAM makes the buzzer crackle and the board heat up, the board is V1 (where GPIO33 (SPIIO4) is connected to the buzzer).
* (optional) Set `upload_port` and `monitor_port`

The default `board` setting is sufficient.

### `platform_tasmota_cenv.ini`

No changes when copying `platform_tasmota_cenv_sample.ini`.

### `tasmota/user_config_overide.h`

This is where the magic happens. Copy the sample per the Tasmota docs, then add (drawing from `tasmota/my_user_config.h`):

```C
// LVGL per https://tasmota.github.io/docs/LVGL/
// --> Optional, but useful for driving the LCD
#define USE_LVGL
#define USE_DISPLAY
#define USE_DISPLAY_LVGL_ONLY
#define USE_UNIVERSAL_DISPLAY
#undef USE_DISPLAY_MODES1TO5
#undef USE_DISPLAY_LCD
#undef USE_DISPLAY_SSD1306
#undef USE_DISPLAY_MATRIX
#undef USE_DISPLAY_SEVENSEG

// On-board devices
// W25Q128JVSIQ 16-Mbit external QIO flash
// --> already handled by the "qio_" in the board config.
// PCF85063 RTC
#define USE_RTC_CHIPS                          // Enable RTC chip support and NTP server - Select only one
#define USE_PCF85063                         // [I2cDriver92] Enable PCF85063 RTC support (I2C address 0x51)
// QMI8658 6-axis IMU
// Buzzer (GPIO-transistor-voicecoil arrangement)
// --> Further configuration is detailed later in this document.
#ifndef USE_BUZZER
#define USE_BUZZER
#endif
// 4-wire SPI ST7789V2 LCD controller, 240x280
#define USE_SPI                                  // Hardware SPI using GPIO12(MISO), GPIO13(MOSI) and GPIO14(CLK) in addition to two user selectable GPIOs(CS and DC)
#define USE_DISPLAY_ST7789                   // [DisplayModel 12] Enable ST7789 module
```

## Post-flash configuration

Once the custom Tasmota firmware is built and flashed, further configuration is needed. Follow the Tasmota docs to configure it and access its web interface.

### Allow ESP32 SPI0 OPI pin assignment

Tasmota's built-in ESP32-S3 configuration prevents the user from assigning any of the in-package PSRAM octal SPI (OPI) pins to peripherals. **When not using the PSRAM on the V1 board**, Tasmota needs to be reconfigured to allow this:

* Main Menu -> Configuration -> Module
    * Observe GPIOs 33 through 37 are not visible
* Main Menu -> Configuration -> Template
    * Set GPIOs 33, 35, 36 to User
    * Save
* Main Menu -> Configuration -> Module
    * Observe the GPIOS are now visible

N.B. Tasmota Templates are a helpful abstraction, but if this doesn't work then go to Main Menu -> Configuration -> Other, set all the GPIO `0`s to `1`s, check the Activate Template button, then click Save.

### Commands

Tasmota supports two different kinds of buzzer, one that takes an on/off signal and one that is driven directly. The buzzer on this board is the latter, so run the following Tasmota [Command](https://tasmota.github.io/docs/Commands/):

`BuzzerPwm 1`

(This is an alias of `SetOption111`.)

### Pin configuration

The next step is to tell Tasmota which pins are connected to which peripherals.

Navigate in the web UI to Main Menu -> Configuration -> Module.

**Reminder: this is currently for V1 hardware.**

* GPIO0 - Button - 1 (this is the middle button on the side of the board)
* GPIO1 - ADC Input
* GPIO4 - SPI DC - 1
* GPIO5 - SPI CS - 1
* GPIO6 - SPI CLK - 1
* GPIO7 - SPI MOSI - 1
* GPIO8 - Display Rst
* GPIO10 - I2C SCL - 1
* GPIO11 - I2C SDA - 1
* GPIO12 - Option A - 3 (this can be any unused pin; toggling it runs the on/off commands for the screen)
* GPIO15 - Backlight
* GPIO33 - Buzzer
    * This can be validated with the Tasmota Command `Buzzer 2,3`

N.B. The V1 schematic labels the display SPI clock and data pins with I2C names. This is clarified in the LVGL sample from the Waveshare wiki for the board.

TODO:

* GPIO38 is the IMU interrupt
* GPIO35 is SYS_EN, but I don't understand the circuit yet
* GPIO36 is SYS_OUT, but I don't understand the circuit yet
* GPIO41 is the RTC interrupt
* GPIO43/44 are a UART TX/RX pair (U0TXD/U0RXD)
* Several other GPIOs are mapped to the breakout header

### Files

Tasmota sets up a filesystem that can be explored via Main Menu -> Tools -> Filesystem. A handful of files are required to finish setting up the display and IMU.

#### display.ini

This file tells the Universal Display Driver how to talk to the screen.

[Field definitions](https://tasmota.github.io/docs/Universal-Display-Driver/)

Sample: `tasmota\displaydesc\ST7789_172x320_Waveshare_esp32c6_lcd_1_47.ini`

The adjacent `ST7789_display.ini` sample includes touchscreen configuration, but this is not for the touch module.

Copy the contents of the accompanying `display.ini` to the device filesystem.

Notes:

* The `*` in the `:H` line are filled in by the Module pin configuration but could be hardcoded instead.
* Loading/reloading display.ini requires a reboot.
* `21,80` in the `:I` section and `:i,21,20` should be, if the datasheet is to be trusted, reversed to `20,80` and `:i,20,21`. As it stands, though, `21` in practice disables inversion; it is possible this is due to an unrelated misconfiguration (perhaps in the LVGL pixel layout configuration). It matches what the sample code does during initialization. This can be experimented with using the `DisplayInvert <n>` Tasmota Command.

TODO: The rotation offsets (`14` on the `:0` line) need to be confirmed for `:1` through `:3`. This can be tested with a good screen layout and the `DisplayRotate <n>` Tasmota Command.

TODO: Toggle the backlight

#### autoexec.be

On every boot, Tasmota will run `autoexec.be` from the filesystem. The one in this directory will load the IMU driver and start HASPmota.

TODO: figure out what is at I2C 0x7E

#### pages.jsonl

HASPmota is a JSON-based way to easily and concisely describe LVGL GUIs. The `pages.jsonl` file in this folder, when placed in the root of the filesystem and together with `haspmota.start()` in `autoexec.be`, will draw a simple UI and graph the X and Y values coming out of the IMU.

# TODO

See TODO markers throughout the document.
