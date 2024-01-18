//! This module allows us to run tasks easily.

use std::error::Error as StdError;
use std::process::Stdio;
use std::result::Result as StdResult;
use std::sync::{mpsc, mpsc::Sender, Arc, RwLock};

use uuid::Uuid;

use futures::stream::StreamExt;

use signal_hook::consts::signal::*;
use signal_hook_tokio::Signals;

use serde::{Deserialize, Serialize};

use tokio::fs::{create_dir_all, remove_dir_all, File};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::Command;

use lapin::options::{
    BasicAckOptions, BasicCancelOptions, BasicConsumeOptions, BasicPublishOptions, BasicQosOptions,
    QueueDeclareOptions,
};
use lapin::types::FieldTable;
use lapin::{BasicProperties, Channel, Connection, ConnectionProperties, Consumer};

use ergol::tokio;

use rocket::http::{ContentType, Status};
use rocket::serde::json::json;

use crate::command::run_command;
use crate::config::Config;
use crate::db::capsule::Capsule;
use crate::db::stats::{TaskStat, TaskStatType};
use crate::db::task_status::TaskStatus;
use crate::s3::S3;
use crate::websockets::{Notifier, WebSockets};
use crate::{Db, Error, Pool, Result, HARSH};

/// The type of tasks.
#[derive(Serialize, Deserialize)]
pub enum Task {
    /// A gos production (first i32 is capsule id, second is gos).
    ProduceGos(i32, i32),

    /// A capsule production.
    ProduceCapsule(i32),

    /// A capsule publication,
    PublishCapsule(i32),
}

impl Task {
    /// Executes the task.
    ///
    /// If you want to launch a task from polymny server, you should use the trigger function
    /// istead.
    async fn run(self, db: Db, config: &Config, notifier: &Notifier) -> Result<()> {
        match self {
            Task::ProduceGos(id, gos) => produce_gos(id, gos, &db, config, notifier).await,
            Task::ProduceCapsule(id) => produce_capsule(id, &db, config, notifier).await,
            Task::PublishCapsule(id) => publish_capsule(id, &db, config, notifier).await,
        }
    }
}

/// A struct that helps us running tasks.
pub enum TaskRunner {
    /// Runs the task locally and asynchronously.
    Local(Pool, Config, WebSockets),

    /// Sends a rabbitmq message to a worker so that it can run the task.
    RabbitMq(Channel),
}

impl TaskRunner {
    /// Creates a local task runner.
    pub fn local(pool: Pool, config: Config, socks: WebSockets) -> TaskRunner {
        TaskRunner::Local(pool, config, socks)
    }

    /// Wraps the rabbitmq connection in the task runner.
    pub fn from_rabbitmq_channel(channel: Channel) -> TaskRunner {
        TaskRunner::RabbitMq(channel)
    }

    /// Creates a rabbit mq task runner from the rabbit mq url.
    pub async fn connect(url: &str) -> StdResult<TaskRunner, lapin::Error> {
        let options = ConnectionProperties::default()
            .with_executor(tokio_executor_trait::Tokio::current())
            .with_reactor(tokio_reactor_trait::Tokio);

        let connection = Connection::connect(url, options).await?;
        let channel = connection.create_channel().await?;

        Ok(TaskRunner::RabbitMq(channel))
    }

    /// Triggers a task.
    pub async fn trigger(&self, task: Task) -> Result<()> {
        match self {
            TaskRunner::Local(pool, config, socks) => {
                let db = Db(pool
                    .get()
                    .await
                    .map_err(|_| Error(Status::InternalServerError))?);

                let config = config.clone();
                let socks = socks.clone();

                tokio::spawn(async move {
                    task.run(db, &config, &Notifier::from_websockets(socks))
                        .await
                        .ok();
                });
            }
            TaskRunner::RabbitMq(channel) => {
                channel
                    .basic_publish(
                        "",
                        "tasks",
                        BasicPublishOptions::default(),
                        rocket::serde::json::to_string(&task)
                            .map_err(|_| Error(Status::InternalServerError))?
                            .as_bytes(),
                        BasicProperties::default(),
                    )
                    .await
                    .map_err(|_| Error(Status::InternalServerError))?
                    .await
                    .map_err(|_| Error(Status::InternalServerError))?;
            }
        }
        Ok(())
    }
}

/// Gos production task.
pub async fn produce_gos(
    capsule_id: i32,
    gos_id: i32,
    db: &Db,
    config: &Config,
    socks: &Notifier,
) -> Result<()> {
    let mut capsule = Capsule::get_by_id(capsule_id, &db)
        .await?
        .ok_or(Error(Status::InternalServerError))?;

    let s3 = config.s3.clone().map(S3::new);

    if let Some(s3) = s3.as_ref() {
        let assets = s3.read_dir(&format!("{}/assets/", capsule.id)).await?;
        let assets = assets
            .contents()
            .ok_or(Error(Status::InternalServerError))?;

        create_dir_all(config.data_path.join(format!("{}/assets", capsule.id))).await?;
        create_dir_all(config.data_path.join(format!("{}/tmp", capsule.id))).await?;
        create_dir_all(config.data_path.join(format!("{}/produced", capsule.id))).await?;

        for asset in assets {
            let key = asset.key().ok_or(Error(Status::InternalServerError))?;
            let bytes = s3
                .download(key)
                .await?
                .collect()
                .await
                .map_err(|_| Error(Status::InternalServerError))?;
            let new_path = config.data_path.join(key);
            let mut f = File::create(new_path).await?;
            f.write_all(&bytes.to_vec()).await?;
        }
    }

    // replace null webcamsteeings with default webcam settings
    let mut capsule_clone = capsule.clone();
    for gos in &mut capsule_clone.structure.0 {
        if gos.webcam_settings.is_none() {
            gos.webcam_settings = Some(capsule_clone.webcam_settings.0.clone());
        }
    }

    let mut capsule_info = capsule_clone.popy();

    let child = Command::new("../scripts/popy.py")
        .arg("produce")
        .arg("gos")
        .arg("-c")
        .arg(format!("{}", capsule.id))
        .arg("-g")
        .arg(format!("{}", gos_id))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn();

    let succeed = if let Ok(mut child) = child {
        if let Some(stdin) = child.stdin.as_mut() {
            stdin
                .write_all(capsule_info.to_string().as_bytes())
                .await
                .unwrap();

            child.stdin.unwrap();
            let stdout = child.stdout.take().unwrap();
            let reader = BufReader::new(stdout);

            let mut lines = reader.lines();
            while let Some(line) = lines.next_line().await.unwrap() {
                capsule
                    .notify_gos_production_progress(
                        &HARSH.encode(capsule_id),
                        &gos_id,
                        &format!("{}", line),
                        &db,
                        &socks,
                    )
                    .await
                    .ok();
            }
            true
        } else {
            false
        }
    } else {
        false
    };

    let gos = &mut capsule.structure.0[gos_id as usize];
    gos.produced = if succeed {
        // Update the gos hash.
        let old_hash = gos.produced_hash.clone();
        let hash_thing = capsule_info
            .refresh_gos_hash(gos_id as usize)
            .ok_or(Error(Status::InternalServerError))?;

        if let Some(s3) = s3.as_ref() {
            let key = format!("{}/produced/{}.mp4", capsule.id, &hash_thing);

            s3.upload(config.data_path.join(&key), &key, ContentType::MP4)
                .await
                .ok();

            // Remove produced gos from previous hash (if there was one).
            if let Some(old_hash) = old_hash {
                if old_hash != hash_thing {
                    let key = format!("{}/produced/{}.mp4", capsule.id, &old_hash);
                    s3.remove(&key).await.ok();
                }
            }
        }

        gos.produced_hash = Some(hash_thing);

        TaskStatus::Done
    } else {
        TaskStatus::Idle
    };

    capsule.production_pid = None;
    capsule.save(&db).await.ok();

    if succeed {
        capsule
            .notify_gos_production(&HARSH.encode(capsule_id), &gos_id, &db, &socks)
            .await
            .ok();
    }

    capsule
        .notify_change(&db, &socks, s3.as_ref())
        .await
        .unwrap();

    Ok(())
}

/// Capsule production task.
pub async fn produce_capsule(
    capsule_id: i32,
    db: &Db,
    config: &Config,
    socks: &Notifier,
) -> Result<()> {
    let s3 = config.s3.clone().map(S3::new);

    let mut capsule = Capsule::get_by_id(capsule_id, &db)
        .await?
        .ok_or(Error(Status::InternalServerError))?;

    let output_dir = config
        .data_path
        .join(format!("{}", capsule_id))
        .join("produced");

    let output_path = output_dir.join("capsule.mp4");

    let mut capsule_info = capsule.popy();

    let mut stat = TaskStat::new(TaskStatType::Production, &db).await?;
    stat.start(&db).await.unwrap();

    if let Some(s3) = s3.as_ref() {
        create_dir_all(config.data_path.join(format!("{}/assets", capsule.id))).await?;
        create_dir_all(config.data_path.join(format!("{}/tmp", capsule.id))).await?;
        create_dir_all(config.data_path.join(format!("{}/produced", capsule.id))).await?;

        let assets = s3.read_dir(&format!("{}/assets/", capsule.id)).await?;
        let assets = assets
            .contents()
            .ok_or(Error(Status::InternalServerError))?;

        for asset in assets {
            let key = asset.key().ok_or(Error(Status::InternalServerError))?;
            let bytes = s3
                .download(key)
                .await?
                .collect()
                .await
                .map_err(|_| Error(Status::InternalServerError))?;
            let new_path = config.data_path.join(key);
            let mut f = File::create(new_path).await?;
            f.write_all(&bytes.to_vec()).await?;
        }

        let assets = s3.read_dir(&format!("{}/produced/", capsule.id)).await?;

        // If we produce a capsule where no grain has been produced before, there will be nothing
        // with the <capsule_id>/produced/ prefix on s3, but we don't need to fetch anything
        if let Some(assets) = assets.contents() {
            for asset in assets {
                let key = asset.key().ok_or(Error(Status::InternalServerError))?;
                let bytes = s3
                    .download(key)
                    .await?
                    .collect()
                    .await
                    .map_err(|_| Error(Status::InternalServerError))?;
                let new_path = config.data_path.join(key);
                let mut f = File::create(new_path).await?;
                f.write_all(&bytes.to_vec()).await?;
            }
        }
    }

    let child = Command::new("../scripts/popy.py")
        .arg("produce")
        .arg("capsule")
        .arg("-c")
        .arg(format!("{}", capsule.id))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn();

    let succeed = if let Ok(mut child) = child {
        capsule.production_pid = child.id().map(|x| x as i32);
        capsule.save(&db).await.ok();

        if let Some(stdin) = child.stdin.as_mut() {
            stdin
                .write_all(capsule_info.to_string().as_bytes())
                .await
                .unwrap();

            child.stdin.unwrap();
            let stdout = child.stdout.take().unwrap();
            let reader = BufReader::new(stdout);

            let mut lines = reader.lines();
            while let Some(line) = lines.next_line().await.unwrap() {
                capsule
                    .notify_capsule_production_progress(
                        &HARSH.encode(capsule.id),
                        &format!("{}", line),
                        &db,
                        &socks,
                    )
                    .await
                    .ok();
            }
            true
        } else {
            false
        }
    } else {
        false
    };

    stat.end(&db).await.unwrap();

    let mut new_capsule = Capsule::get_by_id(capsule_id, &db)
        .await?
        .ok_or(Error(Status::InternalServerError))?;

    new_capsule.produced = if succeed {
        for i in 0..capsule.structure.0.len() {
            let gos_hash = capsule_info
                .refresh_gos_hash(i)
                .ok_or(Error(Status::InternalServerError))?;

            let previous_hash = new_capsule.structure.0[i].produced_hash.clone();

            if let Some(grain) = new_capsule.structure.0.get_mut(i) {
                if let Some(s3) = s3.as_ref() {
                    s3.upload(
                        output_dir.join(&format!("{}.mp4", gos_hash)),
                        &format!("{}/produced/{}.mp4", capsule.id, gos_hash),
                        ContentType::MP4,
                    )
                    .await
                    .ok();

                    if let Some(previous_hash) = previous_hash {
                        if previous_hash != gos_hash {
                            s3.remove(&format!("{}/produced/{}.mp4", capsule.id, previous_hash))
                                .await
                                .ok();
                        }
                    }
                }

                grain.produced_hash = Some(gos_hash);
            } else {
                // Something awful happened here
            }
        }

        let capsule_hash = capsule_info.refresh_hash();
        new_capsule.produced_hash = Some(capsule_hash);

        if let Some(s3) = s3.as_ref() {
            s3.upload(
                &output_path,
                &format!("{}/produced/capsule.mp4", capsule.id),
                ContentType::MP4,
            )
            .await
            .ok();
        }

        TaskStatus::Done
    } else {
        TaskStatus::Idle
    };

    // Update the produced field of the GOSs.
    for i in 0..capsule.structure.0.len() {
        if let Some(gos) = new_capsule.structure.0.get_mut(i) {
            gos.produced = new_capsule.produced;
        } else {
            // Something awful happened here.
        }
    }

    let mut capsule = new_capsule;

    let output = run_command(&vec![
        "../scripts/popy.py",
        "duration",
        "-f",
        output_path.to_str().unwrap(),
    ]);

    match &output {
        Ok(o) => {
            let line = ((std::str::from_utf8(&o.stdout)
                .map_err(|_| Error(Status::InternalServerError))
                .unwrap()
                .trim()
                .parse::<f32>()
                .unwrap())
                * 1000.) as i32;

            capsule.duration_ms = line;
            capsule.save(&db).await.ok();

            if s3.is_some() {
                remove_dir_all(config.data_path.join(format!("{}", capsule.id))).await?;
            }
        }
        Err(_) => error!("Impossible to get duration"),
    };

    capsule.production_pid = None;
    capsule.save(&db).await.ok();

    if succeed {
        capsule
            .notify_capsule_production(&HARSH.encode(capsule.id), &db, &socks)
            .await
            .ok();

        // user.notify(
        //     &socks,
        //     "Production terminée",
        //     &format!(
        //         "La capsule \"{}\" a été correctement produite.",
        //         capsule.name
        //     ),
        //     &db,
        // )
        // .await
        // .ok();
    } else {
        // user.notify(
        //     &socks,
        //     "Production terminée",
        //     &format!("La production de la capsule \"{}\" a échoué.", capsule.name),
        //     &db,
        // )
        // .await
        // .ok();
    };

    capsule
        .notify_change(&db, &socks, s3.as_ref())
        .await
        .unwrap();

    Ok(())
}

/// Publishes a capsule.
pub async fn publish_capsule(
    capsule_id: i32,
    db: &Db,
    config: &Config,
    socks: &Notifier,
) -> Result<()> {
    let s3 = config.s3.clone().map(S3::new);

    let mut capsule = Capsule::get_by_id(capsule_id, &db)
        .await?
        .ok_or(Error(Status::InternalServerError))?;

    let mut stat = TaskStat::new(TaskStatType::Publication, &db).await?;

    let path = config.data_path.join(format!("{}/produced", capsule_id));

    create_dir_all(&path).await?;

    let input = path.join("capsule.mp4");

    let output = config
        .data_path
        .join(format!("{}", capsule_id))
        .join("published");

    remove_dir_all(&output).await.ok();

    stat.start(&db).await.unwrap();

    if let Some(s3) = s3.as_ref() {
        let key = format!("{}/produced/capsule.mp4", capsule_id);
        let bytes = s3
            .download(&key)
            .await?
            .collect()
            .await
            .map_err(|_| Error(Status::InternalServerError))?;
        let new_path = config.data_path.join(key);
        let mut f = File::create(new_path).await?;
        f.write_all(&bytes.to_vec()).await?;
    }

    let mut child = Command::new("../scripts/popy.py");
    let child = child
        .arg("publish")
        .arg("-i")
        .arg(input)
        .arg("-o")
        .arg(output)
        .arg("-c")
        .arg(format!("{}", capsule.id));

    let child = if capsule.prompt_subtitles {
        child.arg("-p")
    } else {
        child
    };

    let child = child.stdin(Stdio::piped()).stdout(Stdio::piped()).spawn();

    let succeed = if let Ok(mut child) = child {
        capsule.publication_pid = child.id().map(|x| x as i32);
        capsule.save(&db).await.ok();

        if let Some(stdin) = child.stdin.as_mut() {
            stdin
                .write_all(json!(capsule.structure.0).to_string().as_bytes())
                .await
                .unwrap();

            child.stdin.unwrap();
            let stdout = child.stdout.take().unwrap();
            let reader = BufReader::new(stdout);

            let mut lines = reader.lines();
            while let Some(line) = lines.next_line().await.unwrap() {
                capsule
                    .notify_publication_progress(
                        &HARSH.encode(capsule.id),
                        &format!("{}", line),
                        &db,
                        &socks,
                    )
                    .await
                    .ok();
            }

            true
        } else {
            false
        }
    } else {
        false
    };

    stat.end(&db).await.unwrap();

    capsule.published = if succeed {
        if let Some(s3) = s3 {
            let output_dir = format!("{}/published", capsule.id);
            s3.upload_dir(config.data_path.join(&output_dir), &output_dir)
                .await
                .unwrap();

            remove_dir_all(config.data_path.join(format!("{}", capsule.id))).await?;
        }

        TaskStatus::Done
    } else {
        TaskStatus::Idle
    };

    capsule.publication_pid = None;
    capsule.save(&db).await.ok();

    if succeed {
        capsule
            .notify_publication(&HARSH.encode(capsule.id), &db, &socks)
            .await
            .ok();

        // user.notify(
        //     &socks,
        //     "Publication terminée",
        //     &format!(
        //         "La capsule \"{}\" a été correctement publiée.",
        //         capsule.name
        //     ),
        //     &db,
        // )
        // .await
        // .ok();
    } else {
        // user.notify(
        //     &socks,
        //     "Publication échouée",
        //     &format!(
        //         "La publication de la capsule \"{}\" a échoué.",
        //         capsule.name
        //     ),
        //     &db,
        // )
        // .await
        // .ok();
    }

    Ok(())
}

/// Structs that holds all the information about the node on which it's running.
pub struct NodeState {
    /// Number of virtual CPUs available on the node.
    pub cpus: i64,

    /// Number of tasks that are currently running on the node.
    pub tasks: i64,

    /// Whether the worker is currently accepting tasks.
    pub accept_tasks: bool,

    /// The RabbitMQ consumer id.
    pub consumer_id: String,
}

impl NodeState {
    /// Initializes the node state.
    pub fn new() -> NodeState {
        NodeState {
            cpus: num_cpus::get() as i64,
            tasks: 0,
            accept_tasks: true,
            consumer_id: Uuid::new_v4().to_string(),
        }
    }

    /// Creates a consumer with the right settings.
    pub async fn create_consumer(&self, channel: &Channel) -> Result<Option<Consumer>> {
        if !self.accept_tasks {
            return Ok(None);
        }

        let priority = 8192 * self.cpus / 2i64.pow(self.tasks as u32) - self.tasks;

        eprintln!("Creating consumer with priority {}", priority);

        let mut args = FieldTable::default();
        args.insert("x-priority".into(), priority.into());

        let consumer = channel
            .basic_consume(
                "tasks",
                &self.consumer_id,
                BasicConsumeOptions::default(),
                args,
            )
            .await
            .map_err(|_| Error(Status::InternalServerError))?;

        Ok(Some(consumer))
    }
}

/// An arc to a node state.
#[derive(Clone)]
pub struct NodeStateArc(Arc<RwLock<NodeState>>);

impl NodeStateArc {
    /// Initializes the node state.
    pub fn new() -> NodeStateArc {
        NodeStateArc(Arc::new(RwLock::new(NodeState::new())))
    }

    /// Createss a consumer.
    pub async fn create_consumer(&self, channel: &Channel) -> Result<Option<Consumer>> {
        let s = (*self.0).read().unwrap();
        s.create_consumer(channel).await
    }

    /// Shuts the worker down.
    pub async fn shutdown(&self, channel: &Channel) {
        let consumer_id = {
            let mut s = (*self.0).write().unwrap();
            s.accept_tasks = false;
            s.consumer_id.clone()
        };

        self.cancel_consumer(channel, &consumer_id).await;
    }

    /// Increases the number of current tasks.
    pub async fn increase_tasks(&self, channel: &Channel) {
        let consumer_id = {
            let mut s = (*self.0).write().unwrap();
            s.tasks += 1;
            s.consumer_id.clone()
        };

        self.cancel_consumer(channel, &consumer_id).await;
    }

    /// Decreases the number of current tasks.
    pub async fn decrease_tasks(&self, channel: &Channel) {
        let consumer_id = {
            let mut s = (*self.0).write().unwrap();
            s.tasks -= 1;
            s.consumer_id.clone()
        };

        self.cancel_consumer(channel, &consumer_id).await;
    }

    /// Cancels the consumer.
    ///
    /// The worker will recreate another one with the updated values.
    ///
    /// This function takes the `consumer_id` as a parameter even though its technically in
    /// `(*self.0).read().consumer_id`. We do so because when we call this function, we already
    /// performed this operation in order to read or write other parts of the struct, so we can
    /// easily access the consumer id, and because we want to avoid locking again.
    pub async fn cancel_consumer(&self, channel: &Channel, consumer_id: &str) {
        if let Err(e) = channel
            .basic_cancel(consumer_id, BasicCancelOptions { nowait: true })
            .await
        {
            eprintln!("Error cancelling consumer: {}", e);
        }
    }

    /// Checks whether the worker has finished all its tasks and can safely exit.
    pub fn is_finished(&self) -> bool {
        let s = (*self.0).read().unwrap();
        s.accept_tasks == false && s.tasks == 0
    }
}

/// Starts a polymny worker.
pub async fn worker() -> StdResult<(), Box<dyn StdError>> {
    color_backtrace::install();

    let config = Config::from_figment(&rocket::Config::figment());
    let uri = config
        .rabbitmq
        .as_ref()
        .expect("Cannot start rabbitmq worker without rabbitmq url")
        .url
        .clone();

    let pool = ergol::pool(&config.databases.database.url, 32).unwrap();

    let options = ConnectionProperties::default()
        .with_executor(tokio_executor_trait::Tokio::current())
        .with_reactor(tokio_reactor_trait::Tokio);

    let connection = Connection::connect(&uri, options).await?;
    let channel = connection.create_channel().await?;
    channel
        .basic_qos(1, BasicQosOptions { global: false })
        .await?;

    channel
        .queue_declare(
            "tasks",
            QueueDeclareOptions::default(),
            FieldTable::default(),
        )
        .await?;

    let node_state = NodeStateArc::new();

    // This channel is here to that the tasks running asynchronously can send the main thread a
    // message when they're done so that the main thread can safely exit.
    let (sender, receiver) = mpsc::channel();
    let signal_sender = sender.clone();

    let signals = Signals::new(&[SIGHUP, SIGTERM, SIGINT, SIGQUIT])?;
    async fn handle_signals(
        mut signals: Signals,
        sender: Sender<()>,
        channel: Channel,
        node_state: NodeStateArc,
    ) {
        while let Some(signal) = signals.next().await {
            match signal {
                SIGHUP => {
                    // Reload configuration
                    // Reopen the log file
                }
                SIGTERM | SIGINT | SIGQUIT => {
                    eprintln!("received order to shut down");
                    node_state.shutdown(&channel).await;

                    // If we need to turn off the worker, send the message.
                    if node_state.is_finished() {
                        sender.send(()).ok();
                    }
                    break;
                }
                _ => unreachable!(),
            }
        }
    }

    let node_state_clone: NodeStateArc = node_state.clone();
    tokio::spawn(handle_signals(
        signals,
        signal_sender,
        channel.clone(),
        node_state_clone,
    ));

    loop {
        let node_state = node_state.clone();
        let sender = sender.clone();
        let channel = channel.clone();

        if let Some(mut consumer) = node_state.create_consumer(&channel).await? {
            let delivery = match consumer.next().await {
                // A RabbitMQ message was received.
                Some(Ok(delivery)) => delivery,

                // The consumer got canceled, we need to create a new consumer unless the previous one
                // was canceled because of sigkill.
                None => continue,

                // An error occured while consuming the message.
                Some(Err(e)) => {
                    eprintln!("Failed to consume queue message {}", e);
                    continue;
                }
            };

            let config = Config::from_figment(&rocket::Config::figment());
            let db = Db(pool.get().await?);

            delivery
                .ack(BasicAckOptions::default())
                .await
                .expect("Failed to ack send_webhook_event message");

            node_state.increase_tasks(&channel).await;

            tokio::spawn(async move {
                let string = match std::str::from_utf8(&delivery.data) {
                    Ok(string) => string,
                    Err(e) => {
                        eprintln!("Failed to decode utf8 string: {}", e);
                        return;
                    }
                };

                let task: Task = match rocket::serde::json::from_str(&string) {
                    Ok(task) => task,
                    Err(e) => {
                        eprintln!("Failed to decode JSON task: {}", e);
                        return;
                    }
                };

                if let Err(e) = task
                    .run(
                        db,
                        &config,
                        &Notifier::from_rabbitmq_channel(channel.clone()),
                    )
                    .await
                {
                    eprintln!("Error: {}", e);
                }

                node_state.decrease_tasks(&channel).await;

                // If we need to turn off the worker, send the message.
                if node_state.is_finished() {
                    sender.send(()).ok();
                }
            });
        } else {
            // node_state.create_consumer() returned None, it means we need to stop listening.
            break;
        }
    }

    // We reach this part of the code when the worker needs to shutdown.
    // We have to wait until the tokio::spawn tasks end.

    // Everytime an event arrives, the worker checks if its finished, and if so sends a message.
    // This happens when sigkill is received, or when a tasks finishes.

    // We just have to wait for this message to arrive, and then, we know we can safely exit.
    let _ = receiver.recv();

    Ok(())
}
