use linux_embedded_hal::I2cdev;

use ssd1306::{mode::BufferedGraphicsMode, prelude::*, I2CDisplayInterface, Ssd1306};

const ACCEL_CONST: f32 = 16.0 * 9.8 / 32768.0;
const VEL_CONST: f32 = 2000.0 / 32768.0;
const ANGLE_CONST: f32 = 180.0 / 32768.0;

pub fn clean_accel(raw: &[u8]) -> Result<([f32; 3], f32), &'static str> {
    let [raw_accel_x, raw_accel_y, raw_accel_z, raw_temp] = parse_two_bytes_format_from_packet(raw)?[..] else {
        return Err("Failed to destruct vec");
    };

    let accel_x = raw_accel_x as f32 * ACCEL_CONST; // m/s^2
    let accel_y = raw_accel_y as f32 * ACCEL_CONST; // m/s^2
    let accel_z = raw_accel_z as f32 * ACCEL_CONST; // m/s^2

    let temperature = raw_temp as f32 / 100.0;

    Ok(([accel_x, accel_y, accel_z], temperature))
}

pub fn clean_vel(raw: &[u8]) -> Result<[f32; 3], &'static str> {
    let [raw_vel_x, raw_vel_y, raw_vel_z, _] = parse_two_bytes_format_from_packet(raw)?[..] else {
        return Err("Failed to destruct vec");
    };

    let vel_x = raw_vel_x as f32 * VEL_CONST; // degrees/s
    let vel_y = raw_vel_y as f32 * VEL_CONST; // degrees/s
    let vel_z = raw_vel_z as f32 * VEL_CONST; // degrees/s

    Ok([vel_x, vel_y, vel_z])
}

pub fn clean_angle(raw: &[u8]) -> Result<[f32; 3], &'static str> {
    let [raw_angle_x, raw_angle_y, raw_angle_z, _] = parse_two_bytes_format_from_packet(raw)?[..] else {
        return Err("Failed to destruct vec");
    };

    let angle_x = raw_angle_x as f32 * ANGLE_CONST; // degrees
    let angle_y = raw_angle_y as f32 * ANGLE_CONST; // degrees
    let angle_z = raw_angle_z as f32 * ANGLE_CONST; // degrees

    Ok([angle_x, angle_y, angle_z])
}

pub fn clean_mag(raw: &[u8]) -> Result<[f32; 3], &'static str> {
    let [raw_mag_x, raw_mag_y, raw_mag_z, _] = parse_two_bytes_format_from_packet(raw)?[..] else {
        return Err("Failed to destruct vec");
    };

    let mag_x = raw_mag_x as f32;
    let mag_y = raw_mag_y as f32;
    let mag_z = raw_mag_z as f32;

    Ok([mag_x, mag_y, mag_z])
}

pub fn clean_atm_press_and_altitude(raw: &[u8]) -> Result<[f32; 2], &'static str> {
    let [raw_atm_press, raw_altitude] = parse_four_bytes_format_from_packet(raw)?[..] else {
        return Err("Failed to destruct vec");
    };

    let atm_press = raw_atm_press as f32  / 101325.0; // atm
    let altitude = raw_altitude as f32 / 100.0; // meters

    Ok([atm_press, altitude])
}

pub fn clean_longitude_latitude(raw: &[u8]) -> Result<[f64; 2], &'static str> {
    let [longitude_val, latitude_val] = parse_four_bytes_format_from_packet(raw)?[..] else {
        return Err("Failed to destruct vec");
    };

    let longitude = parse_gps(longitude_val);
    let latitude = parse_gps(latitude_val);

    Ok([longitude, latitude])
}

pub fn clean_vel_gps(raw: &[u8]) -> Result<f32, &'static str> {
    let [_, raw_vel_gps] = parse_four_bytes_format_from_packet(raw)?[..] else {
        return Err("Failed to destruct vec");
    };

    let vel_gps = raw_vel_gps as f32 / 1000.0; // km/h

    Ok(vel_gps)
}

fn parse_two_bytes_format_from_packet(raw: &[u8]) -> Result<[i16; 4], &'static str> {
    let byte1_x = raw.get(2).ok_or("Missing byte")?;
    let byte2_x = raw.get(3).ok_or("Missing byte")?;

    let byte1_y = raw.get(4).ok_or("Missing byte")?;
    let byte2_y = raw.get(5).ok_or("Missing byte")?;

    let byte1_z = raw.get(6).ok_or("Missing byte")?;
    let byte2_z = raw.get(7).ok_or("Missing byte")?;

    let byte1_w = raw.get(8).ok_or("Missing byte")?;
    let byte2_w = raw.get(9).ok_or("Missing byte")?;

    let raw_value_x = i16::from_le_bytes([*byte1_x, *byte2_x]);
    let raw_value_y = i16::from_le_bytes([*byte1_y, *byte2_y]);
    let raw_value_z = i16::from_le_bytes([*byte1_z, *byte2_z]);
    let raw_value_w = i16::from_le_bytes([*byte1_w, *byte2_w]);

    Ok([raw_value_x, raw_value_y, raw_value_z, raw_value_w])
}

fn parse_four_bytes_format_from_packet(raw: &[u8]) -> Result<[i32; 2], &'static str> {
    let raw_value_3 = raw.get(5).ok_or("Missing byte")? << 24;
    let raw_value_2 = raw.get(4).ok_or("Missing byte")? << 16;
    let raw_value_1 = raw.get(3).ok_or("Missing byte")? << 8;
    let raw_value_0 = raw.get(2).ok_or("Missing byte")? << 0;

    let first_value = (raw_value_3 | raw_value_2 | raw_value_1 | raw_value_0) as i32;

    let raw_value_3 = raw.get(9).ok_or("Missing byte")? << 24;
    let raw_value_2 = raw.get(8).ok_or("Missing byte")? << 16;
    let raw_value_1 = raw.get(7).ok_or("Missing byte")? << 8;
    let raw_value_0 = raw.get(6).ok_or("Missing byte")? << 0;

    let second_value = (raw_value_3 | raw_value_2 | raw_value_1 | raw_value_0) as i32;
    Ok([first_value, second_value])    
}

fn parse_gps(val: i32) -> f64 {
    let sign = if val < 0 { -1.0 } else { 1.0 };
    let abs = val.abs() as f64;

    let degrees = (abs / 10_000_000.0).floor();
    let minutes = (abs % 10_000_000.0) / 100_000.0;

    sign * (degrees + minutes / 60.0)
}


pub fn init_ssd1306_display() -> Ssd1306<I2CInterface<I2cdev>, DisplaySize128x64, BufferedGraphicsMode<DisplaySize128x64>> {
    let as5600 = I2cdev::new("/dev/i2c-1").unwrap();

    let interface = I2CDisplayInterface::new(as5600);
    let mut disp = Ssd1306::new(interface, DisplaySize128x64, DisplayRotation::Rotate0).into_buffered_graphics_mode();
    disp.init().unwrap();

    disp
}
