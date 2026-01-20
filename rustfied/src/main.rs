// TESTING NEW CHANGES


use std::{
    io::Read,
    sync::{Arc, Mutex},
    time::Duration,
};

use clap::{Arg, Command};
use rppal::gpio::{Event, Gpio, Trigger};
use rustfied::sensor::{
    BikeSensor, BrakePressureSensor, I2CSensor, ThermocoupleSensor, UartSensor,
};

use tokio::sync::Notify;

use rust_socketio::asynchronous::ClientBuilder;

use serde_json::json;

use embedded_graphics::{
    mono_font::{ascii::FONT_10X20, MonoTextStyleBuilder},
    pixelcolor::BinaryColor,
    prelude::*,
    text::{Baseline, Text},
};

use rustfied::utils::init_ssd1306_display;
const SERVER_URL: &str = "http://localhost:3001";
const PORT_NAME: &str = "/dev/serial0";
const BAUD_RATE: u32 = 115200;
const SEND_DATA_ONLINE_INTERVAL: u64 = 250; // 250 ms

#[tokio::main]
async fn main() {
    let cmd = Command::new("rustified")
        .arg(
            Arg::new("mode")
                .short('m')
                .long("mode")
                .value_name("MODE")
                .help("Internet status. Valid options: `on` or `off`")
                .required(true),
        )
        .get_matches();

    let mode_arg = cmd
        .get_one::<String>("mode")
        .expect("main: [ERROR] Failed to get `mode` from command line argument");

    if mode_arg != "on" && mode_arg != "off" {
        panic!("Invalid `mode` in command line argument. Should be `on` or `off`")
    }

    let mode_arg = if mode_arg == "on" { true } else { false };

    let mut button_pin = Gpio::new()
        .expect("main: [ERROR] Failed to create GPIO")
        .get(26)
        .expect("main: [ERROR] Failed to use GPIO 26")
        .into_input_pullup();

    let mut hall_pin = Gpio::new()
        .expect("main: [ERROR] Failed to create GPIO")
        .get(21)
        .expect("main: [ERROR] Failed to use GPIO 21")
        .into_input_pullup();

    let sensor = Arc::new(Mutex::new(BikeSensor::new()));
    let notify = Arc::new(Notify::new());

    let file_sensor_clone = Arc::clone(&sensor);
    let network_clone = Arc::clone(&sensor);
    let display_sensor_clone = Arc::clone(&sensor);
    let button_interrupt_sensor_clone = Arc::clone(&sensor);

    let uart_sensor = Arc::clone(
        &sensor
            .lock()
            .expect("main: [ERROR] Failed to get sensor lock")
            .uart,
    );
    let i2c_sensor = Arc::clone(
        &sensor
            .lock()
            .expect("main: [ERROR] Failed to get sensor lock")
            .i2c,
    );
    let thermocouple_sensor = Arc::clone(
        &sensor
            .lock()
            .expect("main: [ERROR] Failed to get sensor lock")
            .thermocouple,
    );
    let brake_pressure_sensor = Arc::clone(
        &sensor
            .lock()
            .expect("main: [ERROR] Failed to get sensor lock")
            .brake_pressure,
    );

    let uart_notify = Arc::clone(&notify);
    let i2c_notify = Arc::clone(&notify);
    let notify_clone = Arc::clone(&notify);

    let sensor_speed_clone_interrupt = Arc::clone(
        &sensor
            .lock()
            .expect("main: [ERROR] Failed to get sensor lock")
            .hall,
    );

    let is_capturing_data = Arc::new(Mutex::new(true));
    let is_capturing_data_file_clone = Arc::clone(&is_capturing_data);
    let is_capturing_data_network_clone = Arc::clone(&is_capturing_data);

    let button_interrupt_callback = move |_: Event| {
        dbg!("Button pressed!");
        if let Ok(mut guard) = is_capturing_data.lock() {
            *guard = !(*guard); // toggle is_capturing_data

            button_interrupt_sensor_clone
                .lock()
                .unwrap()
                .update_file()
                .unwrap();
        } else {
            println!("button_interrupt_callback: [ERROR] Failed to get is_capturing_data lock")
        }
    };

    button_pin
        .set_async_interrupt(
            Trigger::FallingEdge,
            Some(Duration::from_millis(500)),
            button_interrupt_callback,
        )
        .expect("main: [ERROR] Failed to set button interrupt");

    let hall_interrupt_callback = move |_: Event| {
        println!("------------------------------------------------------------------------------------------ INTERRUPT HALL CALLED");
        if let Ok(mut data_speed) = sensor_speed_clone_interrupt.lock() {
            data_speed.update();
        } else {
            println!(
                "hall_interrupt_callback: [ERROR] Failed to get sensor_speed_clone_interrupt lock"
            )
        }
    };

    hall_pin
        .set_async_interrupt(Trigger::FallingEdge, None, hall_interrupt_callback)
        .expect("main: [ERROR] Failed to set hall interrupt");

    tokio::task::spawn_blocking(move || {
        uart_sensor_task(uart_sensor, uart_notify);
    });

    tokio::task::spawn_blocking(move || {
        i2c_sensor_task(i2c_sensor, i2c_notify);
    });

    let file_handler = tokio::spawn(async move {
        file_task(file_sensor_clone, notify, is_capturing_data_file_clone).await;
    });

    let thermocouple_handler = tokio::spawn(async move {
        thermocouple_sensor_task(thermocouple_sensor).await;
    });

    let brake_pressure_handler = tokio::spawn(async move {
        brake_pressure_sensor_task(brake_pressure_sensor).await;
    });

    let display_handler = tokio::spawn(async move {
        display_task(display_sensor_clone).await;
    });

    // if mode_arg is true, then there's internet connection available and so create a task for the
    // network_handler. Othersise, run without this task.
    if mode_arg {
        let network_handler = tokio::spawn(async move {
            network_task(network_clone, notify_clone, is_capturing_data_network_clone).await;
        });

        let _ = tokio::join!(
            file_handler,
            network_handler,
            thermocouple_handler,
            brake_pressure_handler,
            display_handler,
        );
    } else {
        let _ = tokio::join!(
            file_handler,
            thermocouple_handler,
            brake_pressure_handler,
            display_handler,
        );
    }
}

fn uart_sensor_task(uart_sensor: Arc<Mutex<UartSensor>>, notification: Arc<Notify>) {
    let port = serialport::new(PORT_NAME, BAUD_RATE)
        .timeout(Duration::from_secs(10))
        .open();

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
                            if let Ok(mut uart_lock) = uart_sensor.lock() {
                                uart_lock.buffer.copy_from_slice(data_buf.as_slice());
                                if let Err(e) = uart_lock.update() {
                                    println!(
                                        "uart_sensor_task: [ERROR] Failed to update uart struct: {}",
                                        e
                                    )
                                }
                                uart_lock.is_ready = true;
                                notification.notify_waiters();
                            } else {
                                println!("uart_sensor_task: [ERROR] Failed to get uart_lock")
                            }
                        } else {
                            println!("uart_sensor_task: [ERROR] Failed to read uart sensor data")
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

fn i2c_sensor_task(i2c_sensor: Arc<Mutex<I2CSensor>>, notification: Arc<Notify>) {
    loop {
        {
            match i2c_sensor.lock() {
                Ok(mut i2c_lock) => {
                    if let Err(e) = i2c_lock.update() {
                        println!(
                            "i2c_sensor_task: [ERROR] Failed to update i2c struct: {}",
                            e
                        )
                    }
                    i2c_lock.is_ready = true;
                    notification.notify_waiters();
                }
                Err(e) => {
                    println!("i2c_sensor_task: [ERROR] Failed to get i2c lock: {e}")
                }
            }
        }
        std::thread::sleep(Duration::from_millis(1));
    }
}

async fn thermocouple_sensor_task(thermocouple_sensor: Arc<Mutex<ThermocoupleSensor>>) {
    loop {
        {
            match thermocouple_sensor.lock() {
                Ok(mut thermocouple_lock) => {
                    thermocouple_lock.update();
                }
                Err(e) => {
                    println!(
                        "thermocouple_sensor_task: [ERROR] Failed to get thermocouple lock: {e}"
                    )
                }
            }
        }
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
}

async fn brake_pressure_sensor_task(brake_pressure_sensor: Arc<Mutex<BrakePressureSensor>>) {
    loop {
        {
            match brake_pressure_sensor.lock() {
                Ok(mut brake_pressure_lock) => {
                    brake_pressure_lock.update();
                }
                Err(e) => {
                    println!(
                        "brake_pressure_sensor_task: [ERROR] Failed to get brake_pressure_lock lock: {e}"
                    )
                }
            }
        }
        tokio::time::sleep(Duration::from_millis(1)).await;
    }
}

async fn display_task(bike_sensor: Arc<Mutex<BikeSensor>>) {
    let mut disp = init_ssd1306_display();

    let text_style = MonoTextStyleBuilder::new()
        .font(&FONT_10X20)
        .text_color(BinaryColor::On)
        .build();

    disp.flush()
        .expect("display_task: [ERROR] Failed to flush display before loop");

    loop {
        {
            let _ = disp.clear(BinaryColor::Off);
            match bike_sensor.lock() {
                Ok(bike_sensor_lock) => match bike_sensor_lock.get_display_data() {
                    Ok(display_data) => {
                        let text1 = format!("GPS");
                        let text2 = format!("{:.2}", display_data[0]);
                        let text3 = format!("HALL");
                        let text4 = format!("{:.2}", display_data[1]);
                        let _ = Text::with_baseline(
                            &text1,
                            Point::new(15, 0),
                            text_style,
                            Baseline::Top,
                        )
                        .draw(&mut disp);
                        let _ = Text::with_baseline(
                            &text2,
                            Point::new(0, 20),
                            text_style,
                            Baseline::Top,
                        )
                        .draw(&mut disp);
                        let _ = Text::with_baseline(
                            &text3,
                            Point::new(82, 0),
                            text_style,
                            Baseline::Top,
                        )
                        .draw(&mut disp);
                        let _ = Text::with_baseline(
                            &text4,
                            Point::new(70, 20),
                            text_style,
                            Baseline::Top,
                        )
                        .draw(&mut disp);
                    }
                    Err(e) => {
                        println!("display_task: [ERROR] Failed to get display_data: {e}")
                    }
                },
                Err(e) => {
                    println!("display_task: [ERROR] Failed to get bike_sensor lock: {e}")
                }
            }
        }
        tokio::time::sleep(Duration::from_millis(500)).await;
        let _ = disp.flush();
    }
}

async fn file_task(
    bike_sensor: Arc<Mutex<BikeSensor>>,
    notification: Arc<Notify>,
    is_capturing_data: Arc<Mutex<bool>>,
) {
    loop {
        let should_capture = match is_capturing_data.lock() {
            Ok(guard) => *guard,
            Err(e) => {
                println!(
                    "file_task: [ERROR] Failed to get is_capturing_data lock: {}",
                    e
                );
                false
            }
        };

        if should_capture {
            notification.notified().await;
            match bike_sensor.lock() {
                Ok(bike_sensor_lock) => {
                    if let Err(e) = bike_sensor_lock.write_file() {
                        eprintln!("Error saving to file: {}", e);
                    }
                }
                Err(e) => {
                    println!("file_task: [ERROR] Failed to lock bike_sensor: {}", e);
                }
            }
        }
    }
}

async fn network_task(
    bike_sensor: Arc<Mutex<BikeSensor>>,
    notification: Arc<Notify>,
    is_capturing_data: Arc<Mutex<bool>>,
) {
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
                println!(
                    "network_task: [ERROR] Failed to get is_capturing_data lock: {}",
                    e
                );
                false
            }
        };

        if should_capture {
            notification.notified().await;
            interval.tick().await;
            let sensor_json = bike_sensor
                .lock()
                .unwrap()
                .get_json()
                .expect("Failed to parse to json");

            if let Err(e) = socket.emit("send", sensor_json).await {
                println!("Error while trying to send socket: {}", e);
                std::thread::sleep(Duration::from_secs(1));
                socket = create_socket().await;
                std::thread::sleep(Duration::from_secs(1));
            }
            println!("Last line of the loop")
        }
    }
}
