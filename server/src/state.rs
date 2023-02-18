use std::collections::HashMap;

use tokio::sync::RwLock;

pub struct ServerState {
    pub jobs: RwLock<HashMap<u32, Job>>,
}

impl Default for ServerState {
    fn default() -> Self {
        let mut jobs = HashMap::new();
        jobs.insert(4, Job {
            direction: JobDirection::Materials,
            cargo: 1,
            amount: 100.0,
        });
        Self {
            jobs: jobs.into(),
        }
    }
}

pub struct Job {
    pub direction: JobDirection,
    pub cargo: u8,
    pub amount: f32,
}

#[derive(Clone, Copy)]
#[repr(u8)]
pub enum JobDirection {
    Materials = 0,
    Produce = 1,
}

impl JobDirection {
    pub fn from_u8(value: u8) -> Option<Self> {
        match value {
            0 => Some(JobDirection::Materials),
            1 => Some(JobDirection::Produce),
            _ => None,
        }
    }
}
