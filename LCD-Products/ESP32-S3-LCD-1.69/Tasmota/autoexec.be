load("qmi8658")

import haspmota
haspmota.start()

# The 'val_rule' and 'val_rule_formula' system doesn't work for val2.
def on_accel(vals)
    global.p1b10.val = vals[0] * 100
    global.p1b10.val2 = vals[1] * 100
end
tasmota.add_rule(["QMI8658#x_g","QMI8658#y_g"], on_accel)

tasmota.add_rule("BUTTON1#State", def() import haspmota haspmota.page_show('next') end)

tasmota.add_rule("System#Boot", def() tasmota.cmd("backlog buzzer 2,3") end)
