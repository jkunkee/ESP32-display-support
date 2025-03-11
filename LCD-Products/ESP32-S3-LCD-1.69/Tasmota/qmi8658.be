#- This file provides a basic Tasmota driver in berry-lang for the QMI8658 6-axis IMU. -#

class QMI8658
  var wire # not nil if device detected
  # I have no idea why Tasmota Berry won't allow assignment here.
  var addr
  var REG_WHO_AM_I
  var REG_REVISION_ID
  var REG_CTRL1
  var REG_CTRL2
  var REG_CTRL7
  var REG_STATUS0
  var REG_TIMESTAMP_L
  var REG_TEMP_L
  var REG_AX_L
  var REG_RESET

  def read_reg(reg)
    return self.wire.read(self.addr, reg, 1)
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
    self.REG_WHO_AM_I = 0x00
    self.REG_REVISION_ID = 0x01
    self.REG_CTRL1 = 0x02
    self.REG_CTRL2 = 0x03
    self.REG_CTRL7 = 0x08
    self.REG_STATUS0 = 0x2e
    self.REG_TIMESTAMP_L = 0x30
    self.REG_TEMP_L = 0x33
    self.REG_AX_L = 0x35
    self.REG_RESET = 0x60
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
      var aST = 1 << 7
      var aODR = 0xF << 0
      self.write_reg(self.REG_CTRL2, aODR)

      # CTRL7
      # aEN - enable accelerometer
      var aEN = 1 << 0
      self.write_reg(self.REG_CTRL7, aEN)

      tasmota.delay(1750) # Datasheet states post-reset requires 1.75s to recover
      print("QMI8658 found and initialized")
    end
  end

  def every_second()
    if self.wire == nil return end
    var temp_bytes = self.wire.read_bytes(self.addr, self.REG_TEMP_L, 2)
    var temp = real(temp_bytes.geti(0, 2)) / 256.0
    print("Temp", temp, "C")

    print("TIMESTAMP", self.read_reg(self.REG_TIMESTAMP_L))

    print("STATUS0", self.read_reg(self.REG_STATUS0))

    print("AX_L", self.read_reg(self.REG_AX_L))
  end
end
dr = QMI8658()
tasmota.add_driver(dr)
