use std::{convert::Infallible, sync::Arc};

use tokio::{io::{BufStream, self}, net::TcpStream};

use crate::state::ServerState;

pub struct FactoryClient {
    pub(super) stream: BufStream<TcpStream>,
}

impl FactoryClient {
    pub(super) async fn run(self, _state: Arc<ServerState>) -> io::Result<Infallible> {
        Err(io::Error::new(io::ErrorKind::Other, "Not implemented"))
    }
}
