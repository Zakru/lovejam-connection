use tokio::{io::{self, AsyncWriteExt, AsyncReadExt, AsyncRead, BufStream}, net::TcpStream};

/// Divides the TCP stream into packets in the format
///
/// 2 bytes : big-endian u16 packet length<br>
/// n bytes : packet data
pub(super) struct PacketStream {
    stream: BufStream<TcpStream>,
}

impl PacketStream {
    pub fn new(stream: BufStream<TcpStream>) -> Self {
        Self {
            stream,
        }
    }

    pub async fn recv(&mut self) -> io::Result<Box<[u8]>> {
        let mut buf = vec![0u8; self.stream.read_u16().await?.into()];
        self.stream.read_exact(&mut buf).await?;
        Ok(buf.into_boxed_slice())
    }

    pub async fn send(&mut self, packet: &[u8]) -> io::Result<()> {
        self.stream.write_u16(packet.len().try_into().expect("Packet too long")).await?;
        self.stream.write_all(packet).await?;
        self.stream.flush().await
    }
}

pub(super) async fn expect_read<R: AsyncRead + Unpin>(mut r: R, expect: &[u8]) -> io::Result<bool> {
    let mut buf = vec![0u8; expect.len()];
    r.read_exact(&mut buf).await?;
    Ok(buf == expect)
}

pub(super) async fn error_packet(error: &str) -> io::Result<Vec<u8>> {
    let mut buf = Vec::with_capacity(error.len() + 1);
    buf.write_u8(0xff).await?;
    buf.write_all(error.as_bytes()).await?;
    Ok(buf)
}
