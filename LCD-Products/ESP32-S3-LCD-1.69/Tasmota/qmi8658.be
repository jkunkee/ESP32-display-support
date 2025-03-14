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
  var accel_scale_factor
  var latest_datum

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
      # The datasheet says it's two's complement 5.11, so this should be 1/2048, but the example code in SensorLib uses 1/16384
      # and that appears, empirically, to be correct. This corresponds with MAX_INT16 being +2g, which also fits the docs.
      self.accel_scale_factor = 2.0 / 32768.0
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

  def read_accel()
    # Remember, reading STATUS0 clears the interrupt.
    if (self.read_reg(self.REG_STATUS0) & 0x1) == 0x1
      var raw = self.wire.read_bytes(self.addr, self.REG_TIMESTAMP_L, 3+2+2+2+2) # timestamp, temp, acceleration xyz
      var timestamp = raw.get(0, 3)
      var temp = real(raw.geti(3, 2)) / 256.0
      var x = raw.geti(5, 2) * self.accel_scale_factor
      var y = raw.geti(7, 2) * self.accel_scale_factor
      var z = raw.geti(9, 2) * self.accel_scale_factor
      return {'timestamp':timestamp, 'temp_C': temp, 'x_g': x, 'y_g': y, 'z_g': z}
    end
    return nil
  end

  def every_second()
    if self.wire == nil return end

    print("CTRL2", self.read_reg(self.REG_CTRL2))
    # Force in the direction of the arrows is negative
    var datum = self.read_accel()
    if datum != nil
      print("TIMESTAMP", datum["timestamp"])
      print("Temp", datum["temp_C"], "C")
      print("aX", datum["x_g"], "g")
      print("aY", datum["y_g"], "g")
      print("aZ", datum["z_g"], "g")
      self.latest_datum = datum
    end
    return datum
  end

  def web_sensor()
    if self.wire == nil return end
    if self.latest_datum == nil return end
    import string
    import math
    tasmota.web_send_decimal(string.format('accel #%d t=%0.2fC<br/>x=%0.4fg y=%0.4fg z=%0.4fg<br/>mag=%0.4fg',
      self.latest_datum['timestamp'],
      self.latest_datum['temp_C'],
      self.latest_datum['x_g'],
      self.latest_datum['y_g'],
      self.latest_datum['z_g'],
      math.sqrt(math.pow(self.latest_datum['x_g'], 2) + math.pow(self.latest_datum['y_g'], 2) + math.pow(self.latest_datum['z_g'], 2))
    ))
  end
end

var qmi8658_driver_instance
if qmi8658_driver_instance != nil
  tasmota.remove_driver(qmi8658_driver_instance)
end
qmi8658_driver_instance = QMI8658()
tasmota.add_driver(qmi8658_driver_instance)
