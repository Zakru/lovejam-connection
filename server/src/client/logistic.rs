use std::{convert::Infallible, sync::Arc};

use tokio::{io::{BufStream, self, AsyncBufReadExt, AsyncReadExt, AsyncWriteExt}, net::TcpStream};

use crate::state::ServerState;

use super::packet::{PacketStream, error_packet};

pub struct LogisticClient {
    pub(super) stream: BufStream<TcpStream>,
}

impl LogisticClient {
    pub(super) async fn run(self, state: Arc<ServerState>) -> io::Result<Infallible> {
        let mut stream = PacketStream::new(self.stream);

        loop {
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
                b"list" => {
                    let mut res = Vec::new();
                    res.write_all(b"list\0").await?;

                    {
                        let jobs = state.jobs.read().await;
                        let jobs = jobs.iter().take(6);
                        res.write_u8(jobs.len() as u8).await?;
                        for (&job_id, job) in jobs {
                            res.write_u32(job_id).await?;
                            res.write_u8(job.direction as u8).await?;
                            res.write_u8(job.cargo).await?;
                            res.write_f32(job.amount).await?;
                        }
                    }

                    stream.send(&res).await?;
                },
                b"take" => {
                    let job_id = remaining_packet.read_u32().await?;
                    let job = state.jobs.write().await.remove(&job_id);
                    if let Some(_job) = job {
                        let mut res = Vec::new();
                        res.write_all(b"take\0").await?;
                        res.write_u32(job_id).await?;

                        stream.send(&res).await?;
                    } else {
                        stream.send(&error_packet("Job does not exist").await?).await?;
                    }
                },
                _ => return Err(io::Error::new(io::ErrorKind::InvalidData, "Unknown packet type ID")),
            }

            if remaining_packet.len() != 0 {
                stream.send(&error_packet("Extra bytes in packet").await?).await?;
                return Err(io::Error::new(io::ErrorKind::InvalidData, "Extra bytes in packet"));
            }
        }
    }
}
