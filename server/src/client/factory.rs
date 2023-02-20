use std::{convert::Infallible, sync::{Arc, atomic::Ordering}, future::Future, pin::Pin, task::Poll};

use tokio::{io::{BufStream, self, AsyncBufReadExt, AsyncWriteExt, AsyncReadExt}, net::TcpStream, select, sync::mpsc::{Receiver, channel}};

use crate::state::{ServerState, Job, JobUpdate};

use super::packet::{PacketStream, error_packet};

pub struct FactoryClient {
    pub(super) stream: BufStream<TcpStream>,
}

impl FactoryClient {
    pub(super) async fn run(self, state: Arc<ServerState>) -> io::Result<Infallible> {
        let mut stream = PacketStream::new(self.stream);

        let mut job_listeners = Vec::new();

        loop {
            select! {
                (update, job) = JobListener::new(&mut job_listeners) => {
                    let mut res = Vec::new();
                    match update {
                        JobUpdate::Taken => res.write_all(b"taken\0").await?,
                        JobUpdate::Completed => res.write_all(b"completed\0").await?,
                    }

                    res.write_u32(job).await?;

                    stream.send(&res).await?;
                },
                res = stream.readable() => {
                    res?;
                    let packet = stream.recv().await?;
                    if packet.len() == 0 {
                        return Err(io::Error::new(io::ErrorKind::InvalidData, "Empty packet"));
                    }

                    let mut remaining_packet = &*packet;
                    let mut type_id = Vec::new();
                    let type_id_len = remaining_packet.read_until(0, &mut type_id).await?;
                    if type_id[type_id_len - 1] == 0 {
                        type_id.pop();
                    }

                    match &*type_id {
                        b"post" => {
                            let cargo_length = remaining_packet.read_u8().await?;

                            let mut cargo = vec![0u8; cargo_length.into()];
                            remaining_packet.read_exact(&mut cargo).await?;
                            let cargo = String::from_utf8(cargo).map_err(|e|
                                io::Error::new(io::ErrorKind::InvalidData, format!("invalid utf-8 cargo: {}", e)))?;

                            let amount = remaining_packet.read_f32().await?;

                            let job_id = state.job_counter.fetch_add(1, Ordering::Relaxed);
                            let (sender, receiver) = channel(2);

                            state.jobs.write().await.insert(job_id, Job {
                                cargo,
                                amount,
                                sender,
                            });

                            let mut res = Vec::new();
                            res.write_all(b"post\0").await?;
                            res.write_u32(job_id).await?;

                            stream.send(&res).await?;

                            job_listeners.push(JobReference::new(job_id, receiver));
                        },
                        _ => return Err(io::Error::new(io::ErrorKind::InvalidData, "Unknown packet type ID")),
                    }

                    if remaining_packet.len() != 0 {
                        stream.send(&error_packet("Extra bytes in packet").await?).await?;
                        return Err(io::Error::new(io::ErrorKind::InvalidData, "Extra bytes in packet"));
                    }
                },
            };
        }
    }
}

struct JobReference {
    id: u32,
    receiver: Receiver<JobUpdate>,
    buffer: Option<JobUpdate>,
}

impl JobReference {
    fn new(id: u32, receiver: Receiver<JobUpdate>) -> Self {
        Self {
            id,
            receiver,
            buffer: None,
        }
    }
}

struct JobListener<'j> {
    jobs: Pin<&'j mut Vec<JobReference>>,
}

impl<'j> JobListener<'j> {
    pub fn new(jobs: &'j mut Vec<JobReference>) -> Pin<Box<Self>> {
        Box::pin(Self {
            jobs: Pin::new(jobs),
        })
    }
}

impl Future for JobListener<'_> {
    type Output = (JobUpdate, u32);

    fn poll(mut self: std::pin::Pin<&mut Self>, cx: &mut std::task::Context<'_>) -> std::task::Poll<Self::Output> {
        let mut result = None;
        self.jobs.retain_mut(|job| {
            let update = match job.buffer.take() {
                Some(u) => u,
                None => match job.receiver.poll_recv(cx) {
                    Poll::Ready(Some(u)) => u,
                    Poll::Ready(None) => return false,
                    Poll::Pending => return true,
                },
            };

            if result.is_none() {
                result = Some((update, job.id));
                update != JobUpdate::Completed
            } else {
                job.buffer = Some(update);
                true
            }
        });

        result.map_or(Poll::Pending, |r| Poll::Ready(r))
    }
}
