#- This file provides a basic Tasmota driver in berry-lang for the QMI8658 6-axis IMU. -#

class QMI8658
  var wire # not null if device detected
  # I have no idea why Tasmota Berry won't allow assignment here.
  var addr
  var REG_WHO_AM_I
  var REG_REVISION_ID

  def init()
    # The datasheet and board schematic suggest this should be 0x6a, but the Waveshare sample
    # defines it as 0x6b:
    # Arduino-v3.0.5\libraries\SensorLib\src\REG\QMI8658Constants.h:33:#define QMI8658_L_SLAVE_ADDRESS                 (0x6B)
    self.addr = 0x6b
    self.REG_WHO_AM_I = 0x00
    self.REG_REVISION_ID = 0x01
    self.wire = tasmota.wire_scan(self.addr)
    if self.wire
      var v = self.wire.read(self.addr, self.REG_WHO_AM_I, 1)
      if v != 0x05
        print("WHO_AM_I returned", v)
        self.wire = nil
        return
      end
      v = self.wire.read(self.addr, self.REG_REVISION_ID, 1)
      if v != 0x68
        print("REVISION_ID returned", v)
        self.wire = nil
        return
      end
    end
  end

  def every_second()
    if self.wire == nil return end
    print("HELLO WORLD", self.wire)
  end
end
dr = QMI8658()
tasmota.add_driver(dr)
