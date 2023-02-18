use std::{convert::Infallible, sync::Arc};

use tokio::{net::TcpStream, io::{self, BufStream, AsyncWriteExt, AsyncReadExt}};

use crate::state::ServerState;

use self::{factory::FactoryClient, logistic::LogisticClient, packet::{expect_read, PacketStream}};

mod factory;
mod logistic;
mod packet;

pub enum ClientConnection {
    Factory(FactoryClient),
    Logistic(LogisticClient),
}

impl ClientConnection {
    pub async fn new(stream: TcpStream) -> io::Result<Self> {
        let mut stream = BufStream::new(stream);
        expect_read(&mut stream, b"connectiongame\01\0").await?;
        stream.write_all(b"connectiongame\01\0").await?;
        stream.flush().await?;

        match stream.read_u8().await? {
            0x01 => Ok(ClientConnection::Factory(FactoryClient { stream })),
            0x02 => Ok(ClientConnection::Logistic(LogisticClient { stream })),
            t => {
                PacketStream::new(stream).send(b"\xffUnknown client type").await?;
                Err(io::Error::new(io::ErrorKind::InvalidData, format!("Unknown client type: {}", t)))
            },
        }
    }

    pub async fn run(self, state: Arc<ServerState>) -> io::Result<Infallible> {
        match self {
            ClientConnection::Factory(factory) => factory.run(state).await,
            ClientConnection::Logistic(logistic) => logistic.run(state).await,
        }
    }
}
