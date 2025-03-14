#-
This file provides a basic Tasmota driver in berry-lang for the QMI8658 6-axis IMU.

Note that it this is based on the much-more-complete 2022 version of the datasheet
from the sample code ZIP file and not on the 2021 version from the board wiki.
-#


class QMI8658
  static var REG_WHO_AM_I = 0x00
  static var REG_REVISION_ID = 0x01
  static var REG_CTRL1 = 0x02
  static var REG_CTRL2 = 0x03
  static var REG_CTRL7 = 0x08
  static var REG_STATUS0 = 0x2e
  static var REG_TIMESTAMP_L = 0x30
  static var REG_TEMP_L = 0x33
  static var REG_AX_L = 0x35
  static var REG_AY_L = 0x37
  static var REG_AZ_L = 0x39
  static var REG_RESET = 0x60

  var wire # not nil if device detected
  var addr

  def read_reg(reg)
    return self.wire.read(self.addr, reg, 1)
  end

  def read_wide_reg(reg, len, isUnsigned)
    var barr = self.wire.read_bytes(self.addr, reg, len)
    if isUnsigned
      return barr.get(0, len)
    else
      return barr.geti(0, len)
    end
  end

  def write_reg(reg, byte)
    var before = self.wire.read(self.addr, reg, 1)
    var write_result = self.wire.write(self.addr, reg, byte, 1)
    var after = self.wire.read(self.addr, reg, 1)
    print("Wrote", byte, "to reg", reg, "with result", write_result, before, "=>", after)
    return write_result
  end

  def init()
    # The datasheet and board schematic seem to suggest this should be 0x6a, but the Waveshare SensorLib
    # suggests that holding  is in the 0x6b configuration
    # defines it as 0x6b:
    # Arduino-v3.0.5\libraries\SensorLib\src\REG\QMI8658Constants.h:33:#define QMI8658_L_SLAVE_ADDRESS                 (0x6B)
    self.addr = 0x6b
    self.wire = tasmota.wire_scan(self.addr)
    if self.wire
      var v = self.read_reg(self.REG_WHO_AM_I)
      if v != 0x05
        print("WHO_AM_I returned", v)
        self.wire = nil
        return
      end

      # The Waveshare samples have examples of running a software reset, but they don't
      # agree with the provided datasheet. Just pave over the existing settings.

      # It might be tempting to also check REG_REVISION_ID, but the datasheet specifies
      # two different values for it (0x68, 0x79) and testing has shown at least a third (0x7c).
      # Also, the data sheet does not suggest different revisions behave differently.
      v = self.read_reg(self.REG_REVISION_ID)
      print("REVISION_ID", v)

      # CTRL1
      # SPI_AI - I2C and SPI auto-increment of address (allows multi-address reads/writes)
      var SPI_AI = 1 << 6
      var SPI_BE = 1 << 5
      self.write_reg(self.REG_CTRL1, SPI_AI)

      # CTRL2
      # Full scale +/-2g
      var aST = 1 << 7
      var aODR = 0xF << 0
      self.write_reg(self.REG_CTRL2, aODR)

      # CTRL7
      # aEN - enable accelerometer
      var aEN = 1 << 0
      self.write_reg(self.REG_CTRL7, aEN)

      var uptime = tasmota.millis()
      if uptime < 1750
        tasmota.delay(1750 - uptime) # Datasheet states post-reset requires 1.75s to recover
      else
        tasmota.delay(3) # Wait for accelerometer to start up (longer if low-pass filter is enabled)
      end

      print("QMI8658 found and initialized")
    end
  end

  def every_second()
    if self.wire == nil return end

    print("Temp", real(self.read_wide_reg(self.REG_TEMP_L, 2, false)) / 256.0, "C")
    print("TIMESTAMP", self.read_wide_reg(self.REG_TIMESTAMP_L, 3, true))
    print("STATUS0", self.read_reg(self.REG_STATUS0))
    print("CTRL2", self.read_reg(self.REG_CTRL2))
    # The datasheet says it's two's complement 5.11, so this should be 1/2048, but the example code in SensorLib uses 1/16384
    # and that appears, empirically, to be correct. This corresponds with MAX_INT16 being +2g, which also fits the docs.
    var accel_scale_factor = 2.0 / 32768.0
    # Force in the direction of the arrows is negative
    print("AX_L", real(self.read_wide_reg(self.REG_AX_L, 2, false)) * accel_scale_factor)
    print("AY_L", real(self.read_wide_reg(self.REG_AY_L, 2, false)) * accel_scale_factor)
    print("AZ_L", real(self.read_wide_reg(self.REG_AZ_L, 2, false)) * accel_scale_factor)
  end
end
dr = QMI8658()
tasmota.add_driver(dr)
