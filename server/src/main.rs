use std::{net::SocketAddr, sync::Arc};

use client::ClientConnection;
use state::ServerState;
use tokio::{net::{TcpListener, ToSocketAddrs, TcpStream}, io};

mod client;
mod state;

async fn handle_client(stream: TcpStream, addr: SocketAddr, state: Arc<ServerState>) {
    if let Err(e) = handle_client_inner(stream, addr, state).await {
        eprintln!("Uncaught error while handling client: {}", e);
    }
}

async fn handle_client_inner(stream: TcpStream, _: SocketAddr, state: Arc<ServerState>) -> io::Result<()> {
    match ClientConnection::new(stream).await {
        Ok(conn) => {
            conn.run(state).await?;
        }
        Err(e) => eprintln!("Error while accepting client: {}", e),
    }

    Ok(())
}

struct Server {
    listener: TcpListener,
    state: Arc<ServerState>,
}

impl Server {
    async fn bind<A: ToSocketAddrs>(addr: A) -> io::Result<Self> {
        Ok(Self {
            listener: TcpListener::bind(addr).await?,
            state: Default::default(),
        })
    }

    async fn run(self) -> ! {
        loop {
            match self.listener.accept().await {
                Ok((stream, addr)) => {
                    tokio::spawn(handle_client(stream, addr, Arc::clone(&self.state)));
                },
                Err(e) => eprintln!("Error while accepting client: {}", e),
            }
        }
    }
}

#[tokio::main]
async fn main() {
    println!("Running server");

    Server::bind("0.0.0.0:5483").await.expect("Failed to bind server")
        .run().await;
}
