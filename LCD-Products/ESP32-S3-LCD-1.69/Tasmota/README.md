
# Using Tasmota on the ESP32-S3-LCD-1.69 board

Note that I don't know if any of the standard ESP32-S3 Tasmota firmwares include all of these options.

On top of that, I think all of this might be done with a pre-made board config, but I haven't read up on how to do that.

## `platform_override.ini`

Copying `platform_override_sample.ini` as described in the docs is a great start. Changes I made:

* Change `default_envs` to `tasmota32s3`
* [optional] Set `upload_port` and `monitor_port`

The default `board` setting is sufficient.

## `platform_tasmota_cenv.ini`

No changes from `platform_tasmota_cenv_sample.ini`.

## `tasmota/user_config_overide.h`

This is where the party happens. Copy the sample, then I added (along with changes for my purposes):

```C
// LVGL per https://tasmota.github.io/docs/LVGL/
#define USE_LVGL
#define USE_DISPLAY
#define USE_DISPLAY_LVGL_ONLY
#define USE_UNIVERSAL_DISPLAY
#undef USE_DISPLAY_MODES1TO5
#undef USE_DISPLAY_LCD
#undef USE_DISPLAY_SSD1306
#undef USE_DISPLAY_MATRIX
#undef USE_DISPLAY_SEVENSEG

// Device list
// W25Q128JVSIQ 16-Mbit external flash is already handled by the board config since it's a pretty standard arrangement.
// PCF85063 RTC
#define USE_RTC_CHIPS                          // Enable RTC chip support and NTP server - Select only one
#define USE_PCF85063                         // [I2cDriver92] Enable PCF85063 RTC support (I2C address 0x51)
// QMI8658 6-axis IMU
  // TODO
// pin-transistor-voice-coil buzzer
// Be sure to also use the BuzzerPwm or SetOption111 Command to 1 and then configure pin 33 as a Buzzer. That
// takes care of the power consumption warning in the Waveshare docs.
#ifndef USE_BUZZER
#define USE_BUZZER
#endif
// 4-wire SPI ST7789V2 LCD controller, 240x280
#define USE_SPI                                  // Hardware SPI using GPIO12(MISO), GPIO13(MOSI) and GPIO14(CLK) in addition to two user selectable GPIOs(CS and DC)
#define USE_DISPLAY_ST7789                   // [DisplayModel 12] Enable ST7789 module
```

## Pin configuration

TODO: note tweak needed to expose GPIO33 for the Buzzer

### Main Menu -> Configuration -> Module

* GPIO0 - Button - 1 (this is the middle button on the side of the board)
* GPIO1 - Option A - 3 (this can be any unused pin; toggling it runs the on/off commands for the screen)
* GPIO4 - SPI DC - 1
* GPIO5 - SPI CS - 1
* GPIO6 - SPI CLK - 1
* GPIO7 - SPI MOSI - 1
* GPIO8 - Display Rst
* GPIO10 - I2C SCL - 1
* GPIO11 - I2C SDA - 1
* GPIO15 - Backlight
* GPIO33 - Buzzer

The screen SPI pin assignments are only clear in the LVGL sample from Waveshare. The schematic (I have a V1 as far as I can tell) uses I2C names on them.

### Main Menu -> Configuration -> Other

Since GPIO33 is, by default, not assignable with the default configuration because it's presumed to be part of the PSRAM+Flash SPI interface, I think.

I ended up going into the Other panel and setting the GPIO33 entry in the GPIO array to `1`, or, well, all of them:

```json
{"NAME":"ESP32S3","GPIO":[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],"FLAG":0,"BASE":1}
```

Don't forget to activate the template.

#### Template option

With my built of Tasmota, which inherited the previous flash's settings, I can't deactivate the Template in the Other panel. It appears that the template could be easily adjusted on the Template page. It's possible this has downstream consequences for the GPIO routing grid. GPIO33 is the buzzer, though, so that needs exposing.

## display.ini

This file tells the Universal Display Driver how to talk to the screen.

[Field definitions](https://tasmota.github.io/docs/Universal-Display-Driver/)

Sample: `tasmota\displaydesc\ST7789_172x320_Waveshare_esp32c6_lcd_1_47.ini`

The adjacent `ST7789_display.ini` sample includes touchscreen configuration, but this is not for the touch module.

In the on-device filesystem, save the following to `display.ini` (WORK IN PROGRESS):

```
:H,ST7789,240,280,16,SPI,1,*,*,*,*,*,*,*,40
:S,2,1,3,0,80,30
:I
01,A0
11,A0
3A,81,55
36,81,00
21,80
13,80
29,A0
:o,28
:O,29
:A,2A,2B,2C
:R,36
:0,C0,00,00,00
:1,A0,00,00,01
:2,00,00,00,02
:3,60,00,00,03
:i,20,21
#
```

Using the `R` section to set the memory layout register to effect rotation is pretty clever...and really the only way to do it on this hardware.

## Display notes

To get the display working, you have to:

* build with SPI display and ST7789 support enabled
* set up the SPI peripheral (GPIOs, fills in the `*`s in display.ini)
* set up the display GPIOs
* copy display.ini into the filesystem
* restart

# TODO

* Get PSRAM working
    * PSRAM cannot be autodetected on the ESP32-S3, so some form of configuration is required to use it.
    * PSRAM is probably needed for LVGL GUI operation; it is for the Berry LVGL demo.
    * The Waveshare docs suggest that PSRAM sucks enough power to heat up the onboard voltage regulator.
* See if setting `board = esp32s3-qio_opi` in `platform_override.ini` will speed up PSRAM access (default is QIO)
* Add driver for QMI8658, maybe in Berry!
* Fix screen offsets (`R` section of `display.ini` second and third columns)
* Decide on splashscreen (`S` section of `display.ini`)
* Figure out how the screen backlight works
* Use IMU driver to control screen orientation
