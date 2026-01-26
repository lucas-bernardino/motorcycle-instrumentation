use std::fmt::Write as _;
use std::io::Write;
use std::{
    fmt,
    sync::{Arc, Mutex},
};

use ads1x1x::ic::{Ads1115, Resolution16Bit};
use ads1x1x::{Ads1x1x, TargetAddr};
use chrono::prelude::*;
use linux_embedded_hal::I2cdev;
use serde_json::json;

use i2cdev::core::*;
use i2cdev::linux::LinuxI2CDevice;

use crate::utils::{clean_accel, clean_angle, clean_gps_vel, clean_vel};

use rppal::gpio::Gpio;


pub struct BikeStateCtx {
    pub wtgahrs1: Arc<Mutex<WTGAHRS1>>, // uart, imu
    pub as5600: Arc<Mutex<AS5600>>, // i2c, steering sensor
    pub max6675: Arc<Mutex<MAX6675>>, // spi, thermocouple temperature sensor
    pub a3144: Arc<Mutex<A3144>>, // digital (interrupt), hall sensor speed
    pub ads1115: Arc<Mutex<ADS1115>>, // spi, brake pressure sensor
    pub file: Arc<Mutex<std::fs::File>>, // save raw data

    pub counter: Arc<Mutex<i32>>,
}

impl fmt::Display for BikeStateCtx {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "Uart -> {}\nI2C -> {}",
            self.wtgahrs1.lock().unwrap(),
            self.as5600.lock().unwrap()
        )
    }
}

impl BikeStateCtx {
    pub fn new() -> BikeStateCtx {
        let time: DateTime<Local> = Local::now();
        let file_name = format!("{}-{}-{}.txt", time.hour(), time.minute(), time.second(),);

        BikeStateCtx {
            wtgahrs1: Arc::new(Mutex::new(WTGAHRS1::new())),
            as5600: Arc::new(Mutex::new(AS5600::new())),
            max6675: Arc::new(Mutex::new(MAX6675::new())),
            a3144: Arc::new(Mutex::new(A3144::new())),
            ads1115: Arc::new(Mutex::new(ADS1115::new())),
            file: Arc::new(Mutex::new(
                std::fs::File::create(file_name)
                    .expect("Failed to create file with the given path"),
            )),
            counter: Arc::new(Mutex::new(0)),
        }
    }

    pub fn update_file(&mut self) -> Result<(), Box<dyn std::error::Error + '_>> {
        let time: DateTime<Local> = Local::now();
        let file_name = format!("{}-{}-{}.txt", time.hour(), time.minute(), time.second(),);

        self.file = Arc::new(Mutex::new(std::fs::File::create(file_name)?));

        Ok(())
    }

    pub fn write_file(&self) -> Result<(), Box<dyn std::error::Error + '_>> {
        let mut wtgahrs1 = self.wtgahrs1.lock()?;
        let mut as5600 = self.as5600.lock()?;
        let max6675 = self.max6675.lock()?;
        let mut a3144 = self.a3144.lock()?;
        let brake_press = self.ads1115.lock()?;

        if wtgahrs1.is_ready && as5600.is_ready {
            let uart_str = wtgahrs1.buffer.iter().fold(String::new(), |mut output, b| {
                let _ = write!(output, "{b:02x}");
                output
            });

            let time: DateTime<Local> = Local::now();
            let microsecond = time.nanosecond() / 1000;

            let time_str = format!(
                "{}:{}:{:02}.{:06}",
                time.hour(),
                time.minute(),
                time.second(),
                microsecond
            );

            a3144.calculate_speed();

            let mut hall_speed = a3144.hall_speed;
            let mut hall_rpm = 60000.0 / a3144.elapse.as_millis() as f32;
            if hall_rpm.is_infinite() {
                hall_rpm = 0.0;
            }

            let data_to_file = format!(
                "{}{}{}#{:.2}${:.2}!{:.2}@~{}\n",
                uart_str,
                time_str,
                as5600.steering_val,
                hall_rpm,
                hall_speed,
                max6675.thermocouple_temperature,
                brake_press.brake_pressure
            );

            // Print raw data to terminal
            println!("{}", data_to_file);

            self.file.lock()?.write_all(data_to_file.as_bytes())?;

            wtgahrs1.is_ready = false;
            as5600.is_ready = false;
        }
        Ok(())
    }

    pub fn get_json(&self) -> Result<serde_json::Value, Box<dyn std::error::Error + '_>> {
        let wtgahrs1 = self.wtgahrs1.lock()?;
        let as5600 = self.as5600.lock()?;
        let max6675 = self.max6675.lock()?;
        let mut a3144 = self.a3144.lock()?;

        let brake_pressure_sensor = self.ads1115.lock()?;

        let mut counter = self.counter.lock()?;

        //'18:25:52.843023'
        let time: DateTime<Local> = Local::now();
        let time_str = format!("{}:{}:{}", time.hour(), time.minute(), time.second(),);

        a3144.calculate_speed();
        let hall_speed = a3144.hall_speed;
        let mut hall_rpm = 60000.0 / a3144.elapse.as_millis() as f32;
        if hall_rpm.is_infinite() {
            hall_rpm = 0.0;
        }

        let json = json!({
            "id": *counter,
            "acel_x": wtgahrs1.acceleration[0],
            "acel_y": wtgahrs1.acceleration[1],
            "acel_z": wtgahrs1.acceleration[2],
            "vel_x": wtgahrs1.angle_velocity[0],
            "vel_y": wtgahrs1.angle_velocity[1],
            "vel_z": wtgahrs1.angle_velocity[2],
            "roll": wtgahrs1.angle[0],
            "pitch": wtgahrs1.angle[0],
            "yaw": wtgahrs1.angle[0],
            "mag_x": 0.0,
            "mag_y": 0.0,
            "mag_z": 0.0,
            "temp": 0.0,
            "esterc": as5600.steering_val,
            "rot": format!("{:.2}", hall_rpm),
            "veloc": 0.0,
            "long": 0.0,
            "lat": 0.0,
            "veloc_hall": format!("{:.2}", hall_speed),
            "altitude": 0.0,
            "termopar1": max6675.thermocouple_temperature,
            "brake_pressure" :((brake_pressure_sensor.brake_pressure - 0.376) / 0.05).abs(),
        });

        *counter += 1;
        Ok(json)
    }

    pub fn get_display_data(&self) -> Result<[f32; 2], Box<dyn std::error::Error + '_>> {
        let wtgahrs1 = self.wtgahrs1.lock()?;
        let mut a3144 = self.a3144.lock()?;
        a3144.calculate_speed();

        Ok([wtgahrs1.gps_vel, a3144.hall_speed])
    }
}

pub struct WTGAHRS1 {
    pub buffer: Vec<u8>,

    pub acceleration: [f32; 3],
    pub angle_velocity: [f32; 3],
    pub angle: [f32; 3],

    pub gps_vel: f32,

    pub is_ready: bool,
}

impl fmt::Display for WTGAHRS1 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "Acceleration: [{}, {}, {}]\nAngle Velocity: [{}, {}, {}]\nAngle: [{}, {}, {}]\n",
            self.acceleration[0],
            self.acceleration[1],
            self.acceleration[2],
            self.angle_velocity[0],
            self.angle_velocity[1],
            self.angle_velocity[2],
            self.angle[0],
            self.angle[1],
            self.angle[2]
        )
    }
}

impl WTGAHRS1 {
    pub fn new() -> WTGAHRS1 {
        let mut buff: Vec<u8> = vec![0; 86];
        buff.insert(0, 0x55);
        buff.insert(1, 0x51);

        WTGAHRS1 {
            buffer: buff,
            acceleration: [0.0; 3],
            angle_velocity: [0.0; 3],
            angle: [0.0; 3],
            gps_vel: 0.0,
            is_ready: true,
        }
    }

    pub fn update(&mut self) -> Result<(), &'static str> {
        let accel_raw = &self.buffer[0..11];
        let angle_vel_raw = &self.buffer[11..22];
        let angle_raw = &self.buffer[22..33];
        let gps_vel_raw = &self.buffer[66..77];

        self.acceleration = clean_accel(accel_raw)?;
        self.angle_velocity = clean_vel(angle_vel_raw)?;
        self.angle = clean_angle(angle_raw)?;
        self.gps_vel = clean_gps_vel(gps_vel_raw)?;

        Ok(())
    }
}

pub struct AS5600 {
    as5600_dev: LinuxI2CDevice,
    pub steering_val: String, //TODO: Why is this a string and not a float? || steering_val -> steering_val
    pub is_ready: bool,
}

impl fmt::Display for AS5600 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Steer: {}", self.steering_val)
    }
}

impl AS5600 {
    pub fn new() -> AS5600 {
        let steering_val = String::from("1.0");
        let as5600_dev = LinuxI2CDevice::new("/dev/i2c-1", 0x36).expect("Failed to connect to I2C");
        AS5600 {
            as5600_dev,
            steering_val,
            is_ready: true,
        }
    }

    pub fn update(&mut self) -> Result<(), String> {
        match self.as5600_dev.smbus_read_byte_data(0x0C) {
            Ok(high_byte_reading) => match self.as5600_dev.smbus_read_byte_data(0x0D) {
                Ok(low_byte_reading) => {
                    let high_byte = (high_byte_reading as u16) << 8;
                    let low_byte = low_byte_reading as u16;

                    let raw_angle = high_byte | low_byte;
                    let angle_degrees = ((raw_angle & 0xFFF) as f64) * 0.08789;

                    self.steering_val = format!("{:.2}", angle_degrees);
                    Ok(())
                }
                Err(e) => {
                    let err_msg = format!("AS5600: [ERROR] Failed to read 0x0D register: {e}");
                    return Err(err_msg);
                }
            },
            Err(e) => {
                let err_msg = format!("AS5600: [ERROR] Failed to read 0x0C register: {e}");
                return Err(err_msg);
            }
        }
    }
}

pub struct MAX6675 {
    cs_pin: rppal::gpio::OutputPin,
    clk_pin: rppal::gpio::OutputPin,
    data_pin: rppal::gpio::InputPin,
    pub thermocouple_temperature: f32,
}

impl MAX6675 {
    pub fn new() -> MAX6675 {
        let mut cs_pin = Gpio::new()
            .expect("MAX6675: [ERROR] Failed to create GPIO")
            .get(27)
            .expect("MAX6675: [ERROR] Failed to use GPIO 27")
            .into_output();
        let clk_pin = Gpio::new()
            .expect("MAX6675: [ERROR] Failed to create GPIO")
            .get(17)
            .expect("MAX6675: [ERROR] Failed to use GPIO 17")
            .into_output();
        let data_pin = Gpio::new()
            .expect("MAX6675: [ERROR] Failed to create GPIO")
            .get(22)
            .expect("MAX6675: [ERROR] Failed to use GPIO 22")
            .into_input();

        cs_pin.set_high();

        MAX6675 {
            cs_pin,
            clk_pin,
            data_pin,

            thermocouple_temperature: 0.0,
        }
    }

    fn read_max6675(&mut self) -> f32 {
        self.cs_pin.set_low();

        let mut bytesin: u16 = 0;
        for _ in 0..16 {
            self.clk_pin.set_low();
            std::thread::sleep(std::time::Duration::from_micros(100));

            bytesin <<= 1;
            let bit = self.data_pin.is_high();
            if bit {
                bytesin |= 1;
            }

            self.clk_pin.set_high();
            std::thread::sleep(std::time::Duration::from_micros(100));
        }

        std::thread::sleep(std::time::Duration::from_millis(1));
        self.cs_pin.set_high();

        let data_16 = (bytesin >> 3) & 0xFFF;
        let temp = (data_16 as f32) * 0.25;
        temp as f32
    }

    pub fn update(&mut self) {
        self.thermocouple_temperature = self.read_max6675();
    }
}



#[derive(Debug, Clone)]
pub struct A3144 {
    wheel_radius: f32,
    pub elapse: std::time::Duration,
    last_time: std::time::Instant,
    pub hall_speed: f32,
}

impl A3144 {
    pub fn new() -> Self {
        Self {
            wheel_radius: 32.0,
            elapse: std::time::Duration::ZERO,
            last_time: std::time::Instant::now(),
            hall_speed: 0.0,
        }
    }

    pub fn update(&mut self) {
        let now = std::time::Instant::now();
        self.elapse = now.duration_since(self.last_time);
        self.last_time = now;
    }

    pub fn calculate_speed(&mut self) {
        if self.elapse.as_millis() > 0 {
            let _rpm = 60000.0 / self.elapse.as_millis() as f32;
            let circ_cm = 2.0 * std::f32::consts::PI * self.wheel_radius;
            let dist_km = circ_cm / 100000.0;
            let km_per_sec = dist_km / (self.elapse.as_millis() as f32 / 1000.0);
            self.hall_speed = (km_per_sec * 3600.0) / 6.0; // 6 imas
        }
    }
}

pub struct ADS1115 {
    pub adc_ctx: Ads1x1x<I2cdev, Ads1115, Resolution16Bit, ads1x1x::mode::OneShot>,
    pub brake_pressure: f32,
}

impl ADS1115 {
    pub fn new() -> Self {
        let i2c_dev = I2cdev::new("/dev/i2c-1")
            .expect("ADS1115: [ERROR] Failed to open /dev/i2c-1");
        let mut adc_ctx = Ads1x1x::new_ads1115(i2c_dev, TargetAddr::default());
        adc_ctx.set_full_scale_range(ads1x1x::FullScaleRange::Within4_096V)
            .expect("ADS1115: [ERROR] Failed to set_full_scale_range");

        Self {
            adc_ctx,
            brake_pressure: 0.0,
        }
    }

    pub fn update(&mut self) {
        let reading = self.adc_ctx.read(ads1x1x::channel::SingleA0);
        match reading {
            Ok(read_val) => {
                let voltage_val = (read_val as f32) * 4.096 / ((i32::pow(2, 16 - 1) - 1) as f32);
                self.brake_pressure = voltage_val;
            }
            Err(linux_embedded_hal::nb::Error::WouldBlock) => {}
            Err(e) => {
                println!("ADS1115: [ERROR] Failed to read ADC. {:#?}", e);
                self.brake_pressure = 0.0 as f32;
            }
        }
    }
}
