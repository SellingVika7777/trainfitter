// Trainfitter - workshop.rs
// Made by SellingVika

use std::fs::{self, File};
use std::io::{self, BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::time::{Duration, SystemTime};

pub const CACHE_REL: &str = "cache/gmsv_workshop";
const MAX_OUTPUT: u64 = 2 * 1024 * 1024 * 1024;
const LZMA_MEMLIMIT: usize = 256 * 1024 * 1024;
const MAX_PARALLEL: usize = 2;
const CACHE_MAX_AGE: Duration = Duration::from_secs(14 * 24 * 3600);
const CACHE_MAX_BYTES: u64 = 20 * 1024 * 1024 * 1024;

static ACTIVE: AtomicUsize = AtomicUsize::new(0);

pub fn slot_available() -> bool {
	ACTIVE.load(Ordering::SeqCst) < MAX_PARALLEL
}

pub fn garrysmod_dir() -> PathBuf {
	let local = PathBuf::from("garrysmod");
	if local.is_dir() {
		return local;
	}
	if let Ok(exe) = std::env::current_exe() {
		if let Some(dir) = exe.parent() {
			for base in [dir.to_path_buf(), dir.join(".."), dir.join("..").join("..")] {
				let candidate = base.join("garrysmod");
				if candidate.is_dir() {
					return candidate;
				}
			}
		}
	}
	local
}

pub fn cache_dir() -> PathBuf {
	garrysmod_dir().join(CACHE_REL)
}

fn cache_name(id: u64, stamp: u32) -> String {
	format!("{}_{}.gma", id, stamp)
}

pub fn lua_path(id: u64, stamp: u32) -> String {
	format!("{}/{}", CACHE_REL, cache_name(id, stamp))
}

fn has_gma_magic(path: &Path) -> bool {
	let mut magic = [0u8; 4];
	match File::open(path) {
		Ok(mut f) => f.read_exact(&mut magic).is_ok() && &magic == b"GMAD",
		Err(_) => false,
	}
}

fn touch(path: &Path) {
	if let Ok(f) = File::options().write(true).open(path) {
		let _ = f.set_modified(SystemTime::now());
	}
}

pub fn cached(id: u64, stamp: u32) -> Option<String> {
	let path = cache_dir().join(cache_name(id, stamp));
	if path.is_file() && has_gma_magic(&path) {
		touch(&path);
		Some(lua_path(id, stamp))
	} else {
		None
	}
}

pub fn prune_cache() {
	let dir = cache_dir();
	let Ok(entries) = fs::read_dir(&dir) else {
		return;
	};
	let now = SystemTime::now();
	let mut files: Vec<(PathBuf, u64, SystemTime)> = Vec::new();
	for entry in entries.flatten() {
		let Ok(meta) = entry.metadata() else {
			continue;
		};
		if !meta.is_file() {
			continue;
		}
		let modified = meta.modified().unwrap_or(now);
		let path = entry.path();
		let is_part = path.to_string_lossy().contains(".part");
		let age = now.duration_since(modified).unwrap_or_default();
		if age > CACHE_MAX_AGE || (is_part && age > Duration::from_secs(3600)) {
			let _ = fs::remove_file(&path);
			continue;
		}
		files.push((path, meta.len(), modified));
	}
	let mut total: u64 = files.iter().map(|f| f.1).sum();
	if total <= CACHE_MAX_BYTES {
		return;
	}
	files.sort_by_key(|f| f.2);
	for (path, len, _) in files {
		if total <= CACHE_MAX_BYTES {
			break;
		}
		if fs::remove_file(&path).is_ok() {
			total = total.saturating_sub(len);
		}
	}
}

fn pick_source(folder: &Path) -> Result<(PathBuf, bool), String> {
	if folder.is_file() {
		let is_gma = folder.extension().map(|e| e.eq_ignore_ascii_case("gma")).unwrap_or(false);
		return Ok((folder.to_path_buf(), is_gma));
	}
	if !folder.is_dir() {
		return Err(format!("install folder does not exist: {}", folder.display()));
	}
	let mut files: Vec<PathBuf> = fs::read_dir(folder)
		.map_err(|e| format!("cannot list {}: {}", folder.display(), e))?
		.filter_map(|e| e.ok())
		.filter(|e| e.file_type().map(|t| t.is_file()).unwrap_or(false))
		.map(|e| e.path())
		.collect();
	files.sort();
	let ext_is = |p: &PathBuf, want: &str| p.extension().map(|e| e.eq_ignore_ascii_case(want)).unwrap_or(false);
	if let Some(p) = files.iter().find(|p| ext_is(p, "gma")) {
		return Ok((p.clone(), true));
	}
	if let Some(p) = files.iter().find(|p| ext_is(p, "bin")) {
		return Ok((p.clone(), false));
	}
	if files.len() == 1 {
		let only = files.remove(0);
		let is_gma = has_gma_magic(&only);
		return Ok((only, is_gma));
	}
	Err(format!("no GMA or compressed payload in {}", folder.display()))
}

struct LimitedWriter<W: Write> {
	inner: W,
	written: u64,
}

impl<W: Write> Write for LimitedWriter<W> {
	fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
		if self.written + buf.len() as u64 > MAX_OUTPUT {
			return Err(io::Error::new(io::ErrorKind::Other, "decompressed addon is larger than 2 GiB"));
		}
		let n = self.inner.write(buf)?;
		self.written += n as u64;
		Ok(n)
	}

	fn flush(&mut self) -> io::Result<()> {
		self.inner.flush()
	}
}

fn decompress(src: &Path, dst: &Path) -> Result<(), String> {
	let mut input = File::open(src).map_err(|e| format!("open {}: {}", src.display(), e))?;
	let mut header = [0u8; 13];
	input.read_exact(&mut header).map_err(|e| format!("read {}: {}", src.display(), e))?;
	let dict = u32::from_le_bytes([header[1], header[2], header[3], header[4]]) as usize;
	let unpacked = u64::from_le_bytes([header[5], header[6], header[7], header[8], header[9], header[10], header[11], header[12]]);
	if header[0] >= 225 {
		return Err("invalid LZMA properties".to_string());
	}
	if dict > LZMA_MEMLIMIT {
		return Err("LZMA dictionary is too large".to_string());
	}
	if unpacked != u64::MAX && unpacked > MAX_OUTPUT {
		return Err("addon is larger than 2 GiB when unpacked".to_string());
	}
	drop(input);
	let input = File::open(src).map_err(|e| format!("open {}: {}", src.display(), e))?;
	let mut reader = BufReader::with_capacity(1 << 20, input);
	let output = File::create(dst).map_err(|e| format!("create {}: {}", dst.display(), e))?;
	let mut writer = LimitedWriter { inner: BufWriter::with_capacity(1 << 20, output), written: 0 };
	let options = lzma_rs::decompress::Options {
		unpacked_size: lzma_rs::decompress::UnpackedSize::ReadFromHeader,
		memlimit: Some(LZMA_MEMLIMIT),
		allow_incomplete: false,
	};
	lzma_rs::lzma_decompress_with_options(&mut reader, &mut writer, &options).map_err(|e| format!("lzma: {:?}", e))?;
	writer.flush().map_err(|e| format!("flush: {}", e))?;
	Ok(())
}

fn copy_gma(src: &Path, dst: &Path) -> Result<(), String> {
	if !has_gma_magic(src) {
		return Err(format!("{} is not a GMA", src.display()));
	}
	let len = fs::metadata(src).map(|m| m.len()).unwrap_or(u64::MAX);
	if len > MAX_OUTPUT {
		return Err("addon is larger than 2 GiB".to_string());
	}
	fs::copy(src, dst).map(|_| ()).map_err(|e| format!("copy {}: {}", src.display(), e))
}

fn prune_old(dir: &Path, id: u64, keep: &str) {
	let prefix = format!("{}_", id);
	if let Ok(entries) = fs::read_dir(dir) {
		for entry in entries.flatten() {
			let name = entry.file_name().to_string_lossy().into_owned();
			if name.starts_with(&prefix) && name != keep {
				let _ = fs::remove_file(entry.path());
			}
		}
	}
}

pub fn extract(id: u64, folder: &str, stamp: u32) -> Result<String, String> {
	if let Some(path) = cached(id, stamp) {
		return Ok(path);
	}
	let dir = cache_dir();
	fs::create_dir_all(&dir).map_err(|e| format!("cannot create {}: {}", dir.display(), e))?;

	let (src, is_gma) = pick_source(Path::new(folder))?;
	let name = cache_name(id, stamp);
	let out = dir.join(&name);
	let tmp = dir.join(format!("{}.part{}", name, std::process::id()));
	let _ = fs::remove_file(&tmp);

	let result = if is_gma { copy_gma(&src, &tmp) } else { decompress(&src, &tmp) };
	if let Err(e) = result {
		let _ = fs::remove_file(&tmp);
		return Err(e);
	}
	if !has_gma_magic(&tmp) {
		let _ = fs::remove_file(&tmp);
		return Err("downloaded payload is not a GMA".to_string());
	}
	if let Err(e) = fs::rename(&tmp, &out) {
		let _ = fs::remove_file(&tmp);
		if out.is_file() && has_gma_magic(&out) {
			return Ok(lua_path(id, stamp));
		}
		return Err(format!("cannot move GMA into cache: {}", e));
	}
	prune_old(&dir, id, &name);
	Ok(lua_path(id, stamp))
}

pub struct Extraction {
	rx: Receiver<Result<String, String>>,
}

pub enum Poll {
	Pending,
	Done(Result<String, String>),
}

impl Extraction {
	pub fn spawn(id: u64, folder: String, stamp: u32) -> Extraction {
		let (tx, rx) = mpsc::channel();
		ACTIVE.fetch_add(1, Ordering::SeqCst);
		let spawned = std::thread::Builder::new().name(format!("gmsv_workshop_{}", id)).spawn({
			let tx = tx.clone();
			move || {
				let res = std::panic::catch_unwind(|| extract(id, &folder, stamp)).unwrap_or_else(|_| Err("extraction thread panicked".to_string()));
				ACTIVE.fetch_sub(1, Ordering::SeqCst);
				let _ = tx.send(res);
			}
		});
		if let Err(e) = spawned {
			ACTIVE.fetch_sub(1, Ordering::SeqCst);
			let _ = tx.send(Err(format!("cannot spawn extraction thread: {}", e)));
		}
		Extraction { rx }
	}

	pub fn poll(&self) -> Poll {
		match self.rx.try_recv() {
			Ok(r) => Poll::Done(r),
			Err(TryRecvError::Empty) => Poll::Pending,
			Err(TryRecvError::Disconnected) => Poll::Done(Err("extraction thread vanished".to_string())),
		}
	}
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn decompresses_legacy_bin() {
		let Ok(src) = std::env::var("GMSV_TEST_BIN") else {
			return;
		};
		let dst = std::env::temp_dir().join("gmsv_workshop_test.gma");
		decompress(Path::new(&src), &dst).expect("decompress");
		assert!(has_gma_magic(&dst));
		let _ = fs::remove_file(dst);
	}
}
