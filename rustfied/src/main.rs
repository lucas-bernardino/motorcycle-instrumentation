use std::{
    io::Read,
    sync::{Arc, Mutex},
    time::Duration,
};

use clap::{Arg, Command};
use rppal::gpio::{Event, Gpio, Trigger};
use rustfied::sensor::{
    BikeStateCtx, ADS1115, AS5600, MAX6675, WTGAHRS1,
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

    let bike_state_ctx = Arc::new(Mutex::new(BikeStateCtx::new()));
    let notify = Arc::new(Notify::new());

    let file_ctx_clone = Arc::clone(&bike_state_ctx);
    let network_ctx_clone = Arc::clone(&bike_state_ctx);
    let display_ctx_clone = Arc::clone(&bike_state_ctx);
    let button_interrupt_ctx_clone = Arc::clone(&bike_state_ctx);

    let wtgahrs1_ctx = Arc::clone(
        &bike_state_ctx
            .lock()
            .expect("main: [ERROR] Failed to get bike_state_ctx lock")
            .wtgahrs1,
    );
    let as5600_ctx = Arc::clone(
        &bike_state_ctx
            .lock()
            .expect("main: [ERROR] Failed to get bike_state_ctx lock")
            .as5600,
    );
    let max6675_ctx = Arc::clone(
        &bike_state_ctx
            .lock()
            .expect("main: [ERROR] Failed to get bike_state_ctx lock")
            .max6675,
    );
    let ads1115_ctx = Arc::clone(
        &bike_state_ctx
            .lock()
            .expect("main: [ERROR] Failed to get bike_state_ctx lock")
            .ads1115,
    );

    let a3144_ctx = Arc::clone(
        &bike_state_ctx
            .lock()
            .expect("main: [ERROR] Failed to get bike_state_ctx lock")
            .a3144,
    );

    let wtgahrs1_notify = Arc::clone(&notify);
    let as5600_notify = Arc::clone(&notify);
    let network_notify = Arc::clone(&notify);

    let is_capturing_data = Arc::new(Mutex::new(true));
    let is_capturing_data_file_clone = Arc::clone(&is_capturing_data);
    let is_capturing_data_network_clone = Arc::clone(&is_capturing_data);

    let button_interrupt_callback = move |_: Event| {
        dbg!("Button pressed!");
        if let Ok(mut guard) = is_capturing_data.lock() {
            *guard = !(*guard); // toggle is_capturing_data

            button_interrupt_ctx_clone
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
            Some(Duration::from_millis(50)),
            button_interrupt_callback,
        )
        .expect("main: [ERROR] Failed to set button interrupt");

    let hall_interrupt_callback = move |_: Event| {
        if let Ok(mut data_speed) = a3144_ctx.lock() {
            data_speed.update();
        } else {
            println!(
                "hall_interrupt_callback: [ERROR] Failed to get a3144_ctx lock"
            )
        }
    };

    hall_pin
        .set_async_interrupt(Trigger::FallingEdge, None, hall_interrupt_callback)
        .expect("main: [ERROR] Failed to set a3144 interrupt");

    let wtgahrs1_task_handler = tokio::task::spawn_blocking(move || {
        wtgahrs1_task(wtgahrs1_ctx, wtgahrs1_notify);
    });

    let as5600_task_handler = tokio::task::spawn_blocking(move || {
        as5600_task(as5600_ctx, as5600_notify);
    });

    let max6675_task_handler = tokio::task::spawn_blocking(move || {
        max6675_task(max6675_ctx);
    });

    let ads1115_task_handler = tokio::task::spawn_blocking(move || {
        ads1115_task(ads1115_ctx);
    });

    let display_task_handler = tokio::task::spawn_blocking(move || {
        display_task(display_ctx_clone);
    });

    let file_task_handler = tokio::spawn(async move {
        file_task(file_ctx_clone, notify, is_capturing_data_file_clone).await;
    });

    // if mode_arg is true, then there's internet connection available and so create a task for the
    // network_task_handler. Othersise, run without this task.
    if mode_arg {
        let network_task_handler = tokio::spawn(async move {
            network_task(network_ctx_clone, network_notify, is_capturing_data_network_clone).await;
        });

        let _ = tokio::join!(
            wtgahrs1_task_handler,
            as5600_task_handler,
            file_task_handler,
            network_task_handler,
            max6675_task_handler,
            ads1115_task_handler,
            display_task_handler,
        );
    } else {
        let _ = tokio::join!(
            wtgahrs1_task_handler,
            as5600_task_handler,
            file_task_handler,
            max6675_task_handler,
            ads1115_task_handler,
            display_task_handler,
        );
    } 
}

fn wtgahrs1_task(wtgahrs1_ctx: Arc<Mutex<WTGAHRS1>>, notification: Arc<Notify>) {
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
                            if let Ok(mut uart_lock) = wtgahrs1_ctx.lock() {
                                uart_lock.buffer.copy_from_slice(data_buf.as_slice());
                                if let Err(e) = uart_lock.update() {
                                    println!(
                                        "wtgahrs1_task: [ERROR] Failed to update wtgahrs1 struct: {}",
                                        e
                                    )
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

fn as5600_task(as5600_ctx: Arc<Mutex<AS5600>>, notification: Arc<Notify>) {
    loop {
        {
            match as5600_ctx.lock() {
                Ok(mut i2c_lock) => {
                    if let Err(e) = i2c_lock.update() {
                        println!(
                            "as5600_task: [ERROR] Failed to update as5600 struct: {}",
                            e
                        )
                    }
                    i2c_lock.is_ready = true;
                    notification.notify_waiters();
                }
                Err(e) => {
                    println!("as5600_task: [ERROR] Failed to get as5600 lock: {e}")
                }
            }
        }
        std::thread::sleep(Duration::from_millis(1));
    }
}

fn max6675_task(max6675_ctx: Arc<Mutex<MAX6675>>) {
    loop {
        {
            match max6675_ctx.lock() {
                Ok(mut thermocouple_lock) => {
                    thermocouple_lock.update();
                }
                Err(e) => {
                    println!(
                        "max6675_task: [ERROR] Failed to get max6675 lock: {e}"
                    )
                }
            }
        }
        std::thread::sleep(Duration::from_millis(250));;
    }
}

fn ads1115_task(ads1115_ctx: Arc<Mutex<ADS1115>>) {
    loop {
        {
            match ads1115_ctx.lock() {
                Ok(mut brake_pressure_lock) => {
                    brake_pressure_lock.update();
                }
                Err(e) => {
                    println!(
                        "ads1115_task: [ERROR] Failed to get brake_pressure_lock lock: {e}"
                    )
                }
            }
        }
        std::thread::sleep(Duration::from_millis(1));
    }
}

fn display_task(bike_state_ctx: Arc<Mutex<BikeStateCtx>>) {
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
            match bike_state_ctx.lock() {
                Ok(bike_state_ctx_lock) => match bike_state_ctx_lock.get_display_data() {
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
                    println!("display_task: [ERROR] Failed to get bike_state_ctx lock: {e}")
                }
            }
        }
        std::thread::sleep(Duration::from_millis(500));
        let _ = disp.flush();
    }
}

async fn file_task (bike_state_ctx: Arc<Mutex<BikeStateCtx>>, notification: Arc<Notify>, is_capturing_data: Arc<Mutex<bool>>) {
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

async fn network_task (bike_state_ctx: Arc<Mutex<BikeStateCtx>>, notification: Arc<Notify>, is_capturing_data: Arc<Mutex<bool>>) {
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
            let sensor_json = bike_state_ctx
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
