//! This module contains everything needed to manage web sockets.

use std::collections::HashMap;
use std::error::Error as StdError;
use std::result::Result as StdResult;
use std::sync::Arc;

use futures::{poll, task::Poll, SinkExt, StreamExt};

use tokio::sync::{Mutex, MutexGuard};

use lapin::message::DeliveryResult;
use lapin::options::{
    BasicAckOptions, BasicConsumeOptions, BasicPublishOptions, BasicQosOptions, QueueBindOptions,
    QueueDeclareOptions,
};
use lapin::types::FieldTable;
use lapin::{BasicProperties, Channel, Connection, ConnectionProperties};

use ergol::tokio;

use rocket::http::Status;
use rocket::serde::json::{json, Value};
use rocket::State as S;

use rocket_ws::result::Error as TError;
use rocket_ws::stream::DuplexStream;
use rocket_ws::{Message, WebSocket};

use crate::db::user::User;
use crate::{Error, Result};

/// The structs that notifies everywhere.
#[derive(Clone)]
pub enum Notifier {
    /// In local, only one server is running, so we can directly send the messages on the
    /// websockets.
    WebSocket(WebSockets),

    /// When using multiple servers, we send the notification on rabbitmq so it can be broadcasted
    /// to every server.
    RabbitMq(Channel),
}

impl Notifier {
    /// Creates a notifier from websockets.
    pub fn from_websockets(socks: WebSockets) -> Notifier {
        Notifier::WebSocket(socks)
    }

    /// Creates a notifier from a rabbitmq channel.
    pub fn from_rabbitmq_channel(channel: Channel) -> Notifier {
        Notifier::RabbitMq(channel)
    }

    /// Sends a message to users.
    pub async fn write_message(&self, id: i32, message: &Value) -> Result<()> {
        match self {
            Notifier::WebSocket(socks) => socks.write_message(id, message.to_string()).await?,
            Notifier::RabbitMq(channel) => {
                let mut value = message.clone();
                let message = value
                    .as_object_mut()
                    .ok_or(Error(Status::InternalServerError))?;

                message.insert(String::from("rabbitmq_user_id"), json!(id));
                channel
                    .basic_publish(
                        "websockets",
                        "",
                        BasicPublishOptions::default(),
                        value.to_string().as_bytes(),
                        BasicProperties::default(),
                    )
                    .await
                    .map_err(|_| Error(Status::InternalServerError))?;
            }
        }

        Ok(())
    }
}

/// The struct that holds the websockets.
#[derive(Clone)]
pub struct WebSockets(Arc<Mutex<HashMap<i32, Vec<DuplexStream>>>>);

impl WebSockets {
    /// Creates a new empty map of websockets.
    pub fn new() -> WebSockets {
        WebSockets(Arc::new(Mutex::new(HashMap::new())))
    }

    /// Locks the websockets.
    pub async fn lock(&self) -> MutexGuard<'_, HashMap<i32, Vec<DuplexStream>>> {
        self.0.lock().await
    }

    /// Send a message to sockets from an id, removing ids that were disconnected.
    pub async fn write_message(&self, id: i32, message: String) -> Result<()> {
        let mut map = self.lock().await;
        let entry = map.entry(id).or_insert(vec![]);
        let mut to_remove = vec![];

        for (i, s) in entry.into_iter().enumerate() {
            let mut count: u32 = 0;
            let should_remove = loop {
                count += 1;

                if count > 50 {
                    // Infinite loop detection
                    to_remove.push(i);
                    info!("INFINITE LOOP DETECTED");
                    break true;
                }

                match poll!(s.next()) {
                    Poll::Ready(Some(Err(TError::ConnectionClosed)))
                    | Poll::Ready(Some(Err(TError::AlreadyClosed)))
                    | Poll::Ready(Some(Ok(Message::Close(_)))) => {
                        to_remove.push(i);
                        break true;
                    }
                    Poll::Ready(None) | Poll::Pending => break false,
                    _ => continue,
                }
            };

            if !should_remove {
                let res = s.send(Message::Text(message.clone())).await;
                if let Err(TError::ConnectionClosed) = res {
                    to_remove.push(i);
                }
            }
        }

        for i in to_remove.into_iter().rev() {
            if entry[i].close(None).await.is_err() {
                info!("cannot close websocket");
            }
            entry.remove(i);
        }

        Ok(())
    }
}

/// Route to connect to the websockets.
#[get("/ws")]
pub async fn websocket(ws: WebSocket, socks: &S<WebSockets>, user: User) -> rocket_ws::Channel {
    let socks = socks.inner();
    let mut socks = socks.0.lock().await;

    ws.channel(move |stream| {
        Box::pin(async move {
            let entry = socks.entry(user.id).or_insert(vec![]);
            entry.push(stream);
            Ok(())
        })
    })
}

// /// The function called when a connection occurs.
// async fn accept_connection(
//     websockets: WebSockets,
//     stream: TcpStream,
//     pool: ergol::Pool,
// ) -> Result<()> {
//     use crate::db::user::User;
//     use crate::Db;
//
//     let db = Db::from_pool(pool).await?;
//
//     let mut stream = tokio_tungstenite::accept_async(stream).await?;
//
//     let msg = stream
//         .next()
//         .await
//         .ok_or(Error(Status::InternalServerError))??;
//
//     if let Message::Text(secret) = msg {
//         let user = User::get_from_session(&secret, &db)
//             .await?
//             .ok_or(Error(Status::InternalServerError))?;
//
//         let mut map = websockets.lock().await;
//         let entry = map.entry(user.id).or_insert(vec![]);
//         entry.push(stream);
//     }
//
//     Ok(())
// }
//
// /// Starts the webscoket server.
// pub async fn websocket(socks: WebSockets, pool: ergol::Pool) {
//     let config = Config::from_figment(&rocket::Config::figment());
//
//     // Create the event loop and TCP listener we'll accept connections on.
//     let try_socket = TcpListener::bind(&config.socket_listen).await;
//     let listener = try_socket.expect("Failed to bind");
//     info!("Websocket server listening on: {}", config.socket_listen);
//
//     while let Ok((stream, _)) = listener.accept().await {
//         let socks = socks.clone();
//         tokio::spawn(accept_connection(socks, stream, pool.clone()));
//     }
// }

/// Connects to the exchange for websockets and forwards messages from other instances.
pub async fn notifier(rabbitmq_url: String, socks: WebSockets) {
    notifier_aux(rabbitmq_url, socks).await.ok();
}

/// Connects to the exchange for websockets and forwards messages from other instances.
pub async fn notifier_aux(
    rabbitmq_url: String,
    socks: WebSockets,
) -> StdResult<(), Box<dyn StdError>> {
    let options = ConnectionProperties::default()
        .with_executor(tokio_executor_trait::Tokio::current())
        .with_reactor(tokio_reactor_trait::Tokio);

    let connection = Connection::connect(&rabbitmq_url, options).await?;
    let channel = connection.create_channel().await?;
    channel
        .basic_qos(1, BasicQosOptions { global: false })
        .await?;

    let queue_options = QueueDeclareOptions {
        passive: false,
        durable: false,
        exclusive: true,
        auto_delete: false,
        nowait: false,
    };

    let queue = channel
        .queue_declare("", queue_options, FieldTable::default())
        .await
        .unwrap();

    channel
        .queue_bind(
            queue.name().as_str(),
            "websockets",
            "",
            QueueBindOptions::default(),
            FieldTable::default(),
        )
        .await
        .unwrap();

    let consumer = channel
        .basic_consume(
            queue.name().as_str(),
            "",
            BasicConsumeOptions::default(),
            FieldTable::default(),
        )
        .await
        .unwrap();

    consumer.set_delegate(move |delivery: DeliveryResult| {
        let socks = socks.clone();

        async move {
            let delivery = match delivery {
                // Carries the delivery alongside its channel
                Ok(Some(delivery)) => delivery,
                // The consumer got canceled
                Ok(None) => return,
                // Carries the error and is always followed by Ok(None)
                Err(error) => {
                    dbg!("Failed to consume queue message {}", error);
                    return;
                }
            };

            delivery
                .ack(BasicAckOptions::default())
                .await
                .expect("Failed to ack send_webhook_event message");

            let string = std::str::from_utf8(&delivery.data).unwrap().to_string();
            let mut value: Value = serde_json::from_str(&string).unwrap();
            let user_id = value["rabbitmq_user_id"].as_i64().unwrap() as i32;
            let editable = value.as_object_mut().unwrap();
            editable.remove("rabbitmq_user_id");
            socks
                .write_message(user_id, value.to_string())
                .await
                .unwrap();
        }
    });

    // We need to wait for ever, otherwise, the process will stop.
    loop {
        tokio::time::sleep(std::time::Duration::from_secs(86400)).await; // Sleep for one day
    }
}
