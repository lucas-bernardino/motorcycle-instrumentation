use std::{
    io::Read,
    sync::{Arc, Mutex},
    time::Duration,
};

use crate::sensor::{BikeStateCtx, ADS1115, AS5600, MAX6675, WTGAHRS1};

use tokio::sync::Notify;

use rust_socketio::asynchronous::ClientBuilder;

use serde_json::json;

use embedded_graphics::{
    mono_font::{ascii::FONT_10X20, MonoTextStyleBuilder},
    pixelcolor::BinaryColor,
    prelude::*,
    text::{Baseline, Text},
};

use crate::utils::init_ssd1306_display;
const SERVER_URL: &str = "http://localhost:3001";
const PORT_NAME: &str = "/dev/serial0";
const BAUD_RATE: u32 = 115200;
const SEND_DATA_ONLINE_INTERVAL: u64 = 250; // 250 ms

pub fn wtgahrs1_task(wtgahrs1_ctx: Arc<Mutex<WTGAHRS1>>, notification: Arc<Notify>) {
    let port = serialport::new(PORT_NAME, BAUD_RATE).timeout(Duration::from_secs(10)).open();

    let mut data_buf = vec![0; 86];
    data_buf.insert(0, 0x55);
    data_buf.insert(1, 0x51);

    match port {
        Ok(mut port) => {
            let mut buff_check: Vec<u8> = vec![0; 2];
            loop {
                if let Ok(_) = port.read_exact(&mut buff_check) {
                    // println!("Buff check: {:02x?}", buff_check);
                    if buff_check.starts_with(&[0x55, 0x51]) {
                        if let Ok(_) = port.read_exact(&mut data_buf[2..]) {
                            // println!("Buff: {:02x?}", data_buf);
                            if let Ok(mut uart_lock) = wtgahrs1_ctx.lock() {
                                uart_lock.buffer.copy_from_slice(data_buf.as_slice());
                                if let Err(e) = uart_lock.update() {
                                    println!("wtgahrs1_task: [ERROR] Failed to update wtgahrs1 struct: {}", e)
                                }
                                uart_lock.is_ready = true;
                                notification.notify_waiters();
                            } else {
                                println!("wtgahrs1_task: [ERROR] Failed to get uart_lock")
                            }
                        } else {
                            println!("wtgahrs1_task: [ERROR] Failed to read wtgahrs1 sensor data")
                        }
                    }
                }
            }
        }
        Err(e) => {
            eprintln!("Failed to open \"{}\". Error: {}", PORT_NAME, e);
            ::std::process::exit(1);
        }
    }
}

pub fn as5600_task(as5600_ctx: Arc<Mutex<AS5600>>) {
    loop {
        {
            match as5600_ctx.lock() {
                Ok(mut as5600_ctx_lock) => {
                    if let Err(e) = as5600_ctx_lock.update() {
                        println!("as5600_task: [ERROR] Failed to update as5600 struct: {}", e)
                    }
                    as5600_ctx_lock.is_ready = true;
                }
                Err(e) => {
                    println!("as5600_task: [ERROR] Failed to get as5600 lock: {e}")
                }
            }
        }
        std::thread::sleep(Duration::from_millis(1));
    }
}

pub fn max6675_task(max6675_ctx: Arc<Mutex<MAX6675>>) {
    loop {
        {
            match max6675_ctx.lock() {
                Ok(mut thermocouple_lock) => {
                    thermocouple_lock.update();
                }
                Err(e) => {
                    println!("max6675_task: [ERROR] Failed to get max6675 lock: {e}")
                }
            }
        }
        std::thread::sleep(Duration::from_millis(250));
    }
}

pub fn ads1115_task(ads1115_ctx: Arc<Mutex<ADS1115>>) {
    loop {
        {
            match ads1115_ctx.lock() {
                Ok(mut brake_pressure_lock) => {
                    brake_pressure_lock.update();
                }
                Err(e) => {
                    println!("ads1115_task: [ERROR] Failed to get brake_pressure_lock lock: {e}")
                }
            }
        }
        std::thread::sleep(Duration::from_millis(1));
    }
}

pub fn display_task(bike_state_ctx: Arc<Mutex<BikeStateCtx>>) {
    let mut disp = init_ssd1306_display();

    let text_style = MonoTextStyleBuilder::new().font(&FONT_10X20).text_color(BinaryColor::On).build();

    disp.flush().expect("display_task: [ERROR] Failed to flush display before loop");

    loop {
        {
            let _ = disp.clear(BinaryColor::Off);
            match bike_state_ctx.lock() {
                Ok(bike_state_ctx_lock) => match bike_state_ctx_lock.get_display_data() {
                    Ok(display_data) => {
                        let text1 = format!("GPS");
                        let text2 = format!("{:.2}", display_data[0]);
                        let text3 = format!("HALL");
                        let text4 = format!("{:.2}", display_data[1]);
                        let _ = Text::with_baseline(&text1, Point::new(15, 0), text_style, Baseline::Top).draw(&mut disp);
                        let _ = Text::with_baseline(&text2, Point::new(0, 20), text_style, Baseline::Top).draw(&mut disp);
                        let _ = Text::with_baseline(&text3, Point::new(82, 0), text_style, Baseline::Top).draw(&mut disp);
                        let _ = Text::with_baseline(&text4, Point::new(70, 20), text_style, Baseline::Top).draw(&mut disp);
                    }
                    Err(e) => {
                        println!("display_task: [ERROR] Failed to get display_data: {e}")
                    }
                },
                Err(e) => {
                    println!("display_task: [ERROR] Failed to get bike_state_ctx lock: {e}")
                }
            }
        }
        std::thread::sleep(Duration::from_millis(500));
        let _ = disp.flush();
    }
}

pub async fn file_task(bike_state_ctx: Arc<Mutex<BikeStateCtx>>, notification: Arc<Notify>, is_capturing_data: Arc<Mutex<bool>>) {
    loop {
        let should_capture = match is_capturing_data.lock() {
            Ok(guard) => *guard,
            Err(e) => {
                println!("file_task: [ERROR] Failed to get is_capturing_data lock: {}", e);
                false
            }
        };

        if should_capture {
            notification.notified().await;
            match bike_state_ctx.lock() {
                Ok(bike_state_ctx_lock) => {
                    if let Err(e) = bike_state_ctx_lock.write_file() {
                        eprintln!("Error saving to file: {}", e);
                    }
                }
                Err(e) => {
                    println!("file_task: [ERROR] Failed to lock bike_state_ctx: {}", e);
                }
            }
        }
    }
}

pub async fn network_task(bike_state_ctx: Arc<Mutex<BikeStateCtx>>, is_capturing_data: Arc<Mutex<bool>>) {
    let duration = Duration::from_millis(SEND_DATA_ONLINE_INTERVAL);
    let mut interval = tokio::time::interval(duration);

    let init_json = json!({
        "contador": 0
    });

    let create_socket = || async {
        ClientBuilder::new(SERVER_URL)
            .namespace("/")
            .connect()
            .await
            .expect("network_task: [ERROR] Socket connection failed: {}")
    };

    let mut socket = create_socket().await;

    reqwest::Client::new()
        .post(format!("{}/button_pressed", SERVER_URL))
        .json(&init_json)
        .send()
        .await
        .expect("network_task: [ERROR] Socket connection failed: {}");

    loop {
        let should_capture = match is_capturing_data.lock() {
            Ok(guard) => *guard,
            Err(e) => {
                println!("network_task: [ERROR] Failed to get is_capturing_data lock: {}", e);
                false
            }
        };

        if should_capture {
            interval.tick().await;
            let sensor_json = bike_state_ctx.lock().unwrap().get_json().expect("Failed to parse to json");

            if let Err(e) = socket.emit("send", sensor_json).await {
                println!("Error while trying to send socket: {}", e);
                tokio::time::sleep(Duration::from_secs(1)).await;
                socket = create_socket().await;
                tokio::time::sleep(Duration::from_secs(1)).await;
            }
            println!("Last line of the loop")
        }
    }
}
