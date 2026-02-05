use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

use clap::{Arg, Command};
use rppal::gpio::{Event, Gpio, Trigger};
use rustfied::{
    sensor::BikeStateCtx,
    tasks::{ads1115_task, as5600_task, display_task, file_task, max6675_task, network_task, wtgahrs1_task},
};

use tokio::sync::Notify;

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

    let mode_arg = cmd.get_one::<String>("mode").expect("main: [ERROR] Failed to get `mode` from command line argument");

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

    let wtgahrs1_ctx = Arc::clone(&bike_state_ctx.lock().expect("main: [ERROR] Failed to get bike_state_ctx lock").wtgahrs1);
    let as5600_ctx = Arc::clone(&bike_state_ctx.lock().expect("main: [ERROR] Failed to get bike_state_ctx lock").as5600);
    let max6675_ctx = Arc::clone(&bike_state_ctx.lock().expect("main: [ERROR] Failed to get bike_state_ctx lock").max6675);
    let ads1115_ctx = Arc::clone(&bike_state_ctx.lock().expect("main: [ERROR] Failed to get bike_state_ctx lock").ads1115);

    let a3144_ctx = Arc::clone(&bike_state_ctx.lock().expect("main: [ERROR] Failed to get bike_state_ctx lock").a3144);

    let wtgahrs1_notify = Arc::clone(&notify);

    let is_capturing_data = Arc::new(Mutex::new(true));
    let is_capturing_data_file_clone = Arc::clone(&is_capturing_data);
    let is_capturing_data_network_clone = Arc::clone(&is_capturing_data);

    let button_interrupt_callback = move |_: Event| {
        dbg!("Button pressed!");
        if let Ok(mut guard) = is_capturing_data.lock() {
            *guard = !(*guard); // toggle is_capturing_data

            button_interrupt_ctx_clone.lock().unwrap().update_file().unwrap();
        } else {
            println!("button_interrupt_callback: [ERROR] Failed to get is_capturing_data lock")
        }
    };

    button_pin
        .set_async_interrupt(Trigger::FallingEdge, Some(Duration::from_millis(50)), button_interrupt_callback)
        .expect("main: [ERROR] Failed to set button interrupt");

    let hall_interrupt_callback = move |_: Event| {
        if let Ok(mut data_speed) = a3144_ctx.lock() {
            data_speed.update();
        } else {
            println!("hall_interrupt_callback: [ERROR] Failed to get a3144_ctx lock")
        }
    };

    hall_pin
        .set_async_interrupt(Trigger::FallingEdge, None, hall_interrupt_callback)
        .expect("main: [ERROR] Failed to set a3144 interrupt");

    let wtgahrs1_task_handler = tokio::task::spawn_blocking(move || {
        wtgahrs1_task(wtgahrs1_ctx, wtgahrs1_notify);
    });

    let as5600_task_handler = tokio::task::spawn_blocking(move || {
        as5600_task(as5600_ctx);
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
            network_task(network_ctx_clone, is_capturing_data_network_clone).await;
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
