import struct

CONSTANTE_1 = 16 * 9.8 / 32768
CONSTANTE_2 = 2000 / 32768
CONSTANTE_3 = 180 / 32768
CONSTANTE_4 = 2000 / 32768




def handleSensor1(sensor_list):
  acel_x = struct.unpack(
      "<h",
      bytearray(
          [int("0x" + sensor_list[4:6], 16),
           int("0x" + sensor_list[6:8], 16)]))[0] * CONSTANTE_1
  acel_y = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[8:10], 16),
          int("0x" + sensor_list[10:12], 16)
      ]))[0] * CONSTANTE_1
  acel_z = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[12:14], 16),
          int("0x" + sensor_list[14:16], 16)
      ]))[0] * CONSTANTE_1
  temp = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[16:18], 16),
          int("0x" + sensor_list[18:20], 16)
      ]))[0] / 100

  return [acel_x, acel_y, acel_z, temp]




def handleSensor2(sensor_list):
  vel_x = struct.unpack(
      "<h",
      bytearray(
          [int("0x" + sensor_list[4:6], 16),
           int("0x" + sensor_list[6:8], 16)]))[0] * CONSTANTE_2
  vel_y = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[8:10], 16),
          int("0x" + sensor_list[10:12], 16)
      ]))[0] * CONSTANTE_2
  vel_z = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[12:14], 16),
          int("0x" + sensor_list[14:16], 16)
      ]))[0] * CONSTANTE_2

  return [vel_x, vel_y, vel_z]




def handleSensor3(sensor_list):
  roll = struct.unpack(
      "<h",
      bytearray(
          [int("0x" + sensor_list[4:6], 16),
           int("0x" + sensor_list[6:8], 16)]))[0] * CONSTANTE_3
  pitch = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[8:10], 16),
          int("0x" + sensor_list[10:12], 16)
      ]))[0] * CONSTANTE_3
  yall = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[12:14], 16),
          int("0x" + sensor_list[14:16], 16)
      ]))[0] * CONSTANTE_3

  return [roll, pitch, yall]




def handleSensor4(sensor_list):
  mag_x = struct.unpack(
      "<h",
      bytearray(
          [int("0x" + sensor_list[4:6], 16),
           int("0x" + sensor_list[6:8], 16)]))[0] * CONSTANTE_3
  mag_y = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[8:10], 16),
          int("0x" + sensor_list[10:12], 16)
      ]))[0] * CONSTANTE_3
  mag_z = struct.unpack(
      "<h",
      bytearray([
          int("0x" + sensor_list[12:14], 16),
          int("0x" + sensor_list[14:16], 16)
      ]))[0] * CONSTANTE_3

  return [mag_x, mag_y, mag_z]


def handleSensor5(sensor_list):
    air_press_atm = float((int("0x" + sensor_list[10:12], 16) << 24 ) | int("0x" + sensor_list[8:10], 16) << 16  | int("0x" + sensor_list[6:8], 16) << 8  | int("0x" + sensor_list[4:6], 16)) / 101325  
    altitude_m = float((int("0x" + sensor_list[18:20], 16) << 24 ) | int("0x" + sensor_list[16:18], 16) << 16  | int("0x" + sensor_list[14:16], 16) << 8  | int("0x" + sensor_list[12:14], 16)) / 100
    return [air_press_atm, altitude_m]


def handleSensor6(sensor_list):
    longtitude = float((int("0x" + sensor_list[10:12], 16) << 24 ) | int("0x" + sensor_list[8:10], 16) << 16  | int("0x" + sensor_list[6:8], 16) << 8  | int("0x" + sensor_list[4:6], 16))  
    latitude = float((int("0x" + sensor_list[18:20], 16) << 24 ) | int("0x" + sensor_list[16:18], 16) << 16  | int("0x" + sensor_list[14:16], 16) << 8  | int("0x" + sensor_list[12:14], 16))
    return [longtitude, latitude]

def handleSensor7(sensor_list):
    velocidade_gps = float((int("0x" + sensor_list[18:20], 16) << 24 ) | int("0x" + sensor_list[16:18], 16) << 16  | int("0x" + sensor_list[14:16], 16) << 8  | int("0x" + sensor_list[12:14], 16)) / 1000
    return velocidade_gps


# acel_x, acel_y, acel_z, temp = handleSensor1(data[0:22])
# vel_x, vel_y, vel_z = handleSensor2(data[22:44])
# roll, pitch, yall = handleSensor3(data[44:66])
# mag_x, mag_y, mag_z = handleSensor4(data[66:88])
# air_press, altitude = handleSensor5(data[88:110])
# longitude, latitude = handleSensor6(data[110:132])
# velocidade_gps = handleSensor7(data[132:154])
# angle = data[176:]