use std::{collections::HashMap, sync::atomic::AtomicU32};

use tokio::sync::{RwLock, mpsc::{Sender, channel}};

pub struct ServerState {
    pub jobs: RwLock<HashMap<u32, Job>>,
    pub job_counter: AtomicU32,
}

impl Default for ServerState {
    fn default() -> Self {
        let mut jobs = HashMap::new();
        jobs.insert(1, Job {
            cargo: "scrap".into(),
            amount: 100.0,
            sender: channel(1).0,
        });
        Self {
            jobs: jobs.into(),
            job_counter: 2.into(),
        }
    }
}

pub struct Job {
    pub cargo: String,
    pub amount: f32,
    pub sender: Sender<JobUpdate>,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum JobUpdate {
    Taken,
    Completed,
}
