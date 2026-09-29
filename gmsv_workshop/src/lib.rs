// Trainfitter - lib.rs
// Made by SellingVika

mod dylib;
mod lua;
mod steam;
mod workshop;

use lua::{Lua, State};
use std::cell::RefCell;
use std::ffi::c_int;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::time::{Duration, Instant};

const VERSION: &str = env!("CARGO_PKG_VERSION");
const TIMER_NAME: &str = "gmsv_workshop_poll";
const TUSERDATA: c_int = 7;

const LOGON_TIMEOUT: Duration = Duration::from_secs(180);
const START_TIMEOUT: Duration = Duration::from_secs(90);
const STALL_TIMEOUT: Duration = Duration::from_secs(240);
const TOTAL_TIMEOUT: Duration = Duration::from_secs(1800);
const QUERY_TIMEOUT: Duration = Duration::from_secs(45);

enum Phase {
	Waiting,
	Requested,
	Extracting(workshop::Extraction),
}

struct Download {
	id: u64,
	callbacks: Vec<c_int>,
	phase: Phase,
	created: Instant,
	requested: Instant,
	progress_at: Instant,
	progress: u64,
	seen_state: bool,
}

enum QueryPhase {
	Waiting,
	Sent { handle: u64, call: u64 },
}

struct Query {
	id: u64,
	callback: c_int,
	phase: QueryPhase,
	created: Instant,
}

enum Finished {
	Download { callbacks: Vec<c_int>, result: Result<String, String>, id: u64 },
	Query { callback: c_int, id: u64, info: Result<Box<QueryInfo>, i32> },
}

struct QueryInfo {
	details: Box<steam::UgcDetails>,
	children: Vec<u64>,
}

#[derive(Default)]
struct Module {
	downloads: Vec<Download>,
	queries: Vec<Query>,
	finished: Vec<Finished>,
	timer_active: bool,
}

thread_local! {
	static MODULE: RefCell<Module> = RefCell::new(Module::default());
}

fn with_module<R>(f: impl FnOnce(&mut Module) -> R) -> R {
	MODULE.with(|m| f(&mut m.borrow_mut()))
}

fn call_global(lua: Lua, name: &str, args: &[&str]) {
	let top = lua.top();
	lua.get_global(name);
	if lua.type_of(-1) != lua::TFUNCTION {
		lua.set_top(top);
		return;
	}
	for a in args {
		lua.push_str(a);
	}
	let _ = lua.pcall(args.len() as c_int, 0);
	lua.set_top(top);
}

fn log(lua: Lua, msg: &str) {
	call_global(lua, "print", &[&format!("[gmsv_workshop] {}", msg)]);
}

fn report_error(lua: Lua, msg: &str) {
	call_global(lua, "ErrorNoHalt", &[&format!("[gmsv_workshop] {}\n", msg)]);
}

fn call_lib(lua: Lua, lib: &str, func: &str, push_args: impl FnOnce(Lua) -> c_int) -> bool {
	let top = lua.top();
	lua.get_global(lib);
	if lua.type_of(-1) != lua::TTABLE {
		lua.set_top(top);
		return false;
	}
	lua.raw_get_field(-1, func);
	if lua.type_of(-1) != lua::TFUNCTION {
		lua.set_top(top);
		return false;
	}
	let nargs = push_args(lua);
	let ok = lua.pcall(nargs, 0).is_ok();
	lua.set_top(top);
	ok
}

fn ensure_timer(lua: Lua) {
	let active = with_module(|m| m.timer_active);
	if active {
		return;
	}
	let created = call_lib(
		lua,
		"timer",
		"Create",
		|l| {
			l.push_str(TIMER_NAME);
			l.push_number(0.2);
			l.push_number(0.0);
			l.push_function(poll);
			4
		},
	);
	with_module(|m| m.timer_active = created);
	if !created {
		report_error(lua, "timer.Create failed, downloads cannot progress");
	}
}

fn stop_timer(lua: Lua) {
	call_lib(
		lua,
		"timer",
		"Remove",
		|l| {
			l.push_str(TIMER_NAME);
			1
		},
	);
	with_module(|m| m.timer_active = false);
}

fn parse_id(lua: Lua, idx: c_int) -> Option<u64> {
	let s = lua.to_string(idx)?;
	let s = s.trim();
	if s.is_empty() || s.len() > 20 || !s.bytes().all(|b| b.is_ascii_digit()) {
		return None;
	}
	s.parse::<u64>().ok().filter(|&id| id > 0)
}

fn store_callback(lua: Lua, idx: c_int) -> Option<c_int> {
	if lua.type_of(idx) != lua::TFUNCTION {
		return None;
	}
	lua.push_value(idx);
	Some(lua.reference())
}

unsafe extern "C" fn download_ugc(state: State) -> c_int {
	let lua = Lua(state);
	let _ = catch_unwind(AssertUnwindSafe(|| {
		let callback = store_callback(lua, 2);
		let now = Instant::now();
		match parse_id(lua, 1) {
			Some(id) => with_module(|m| {
				if let Some(existing) = m.downloads.iter_mut().find(|d| d.id == id) {
					existing.callbacks.extend(callback);
				} else {
					m.downloads.push(Download {
						id,
						callbacks: callback.into_iter().collect(),
						phase: Phase::Waiting,
						created: now,
						requested: now,
						progress_at: now,
						progress: 0,
						seen_state: false,
					});
				}
			}),
			None => with_module(|m| {
				m.finished.push(Finished::Download {
					callbacks: callback.into_iter().collect(),
					result: Err("invalid workshop id".to_string()),
					id: 0,
				})
			}),
		}
		ensure_timer(lua);
	}));
	0
}

unsafe extern "C" fn file_info(state: State) -> c_int {
	let lua = Lua(state);
	let _ = catch_unwind(AssertUnwindSafe(|| {
		let Some(callback) = store_callback(lua, 2) else {
			return;
		};
		match parse_id(lua, 1) {
			Some(id) => with_module(|m| {
				m.queries.push(Query { id, callback, phase: QueryPhase::Waiting, created: Instant::now() });
			}),
			None => with_module(|m| m.finished.push(Finished::Query { callback, id: 0, info: Err(-1) })),
		}
		ensure_timer(lua);
	}));
	0
}

unsafe extern "C" fn status(state: State) -> c_int {
	let lua = Lua(state);
	let (ok, msg) = match steam::fns() {
		Err(e) => (false, e),
		Ok(f) => match steam::connect() {
			Err(e) => (false, e),
			Ok(s) => {
				if s.logged_on() {
					(true, format!("ready ({})", f.versions))
				} else {
					(false, format!("game server is not logged on to Steam yet ({})", f.versions))
				}
			}
		},
	};
	lua.push_bool(ok);
	lua.push_str(&msg);
	2
}

fn step_download(d: &mut Download) -> Option<Result<String, String>> {
	let now = Instant::now();
	if now.duration_since(d.created) > TOTAL_TIMEOUT {
		return Some(Err("download timed out".to_string()));
	}
	match &d.phase {
		Phase::Waiting => {
			let s = match steam::connect() {
				Ok(s) => s,
				Err(e) => {
					return if now.duration_since(d.created) > LOGON_TIMEOUT { Some(Err(e)) } else { None };
				}
			};
			if !s.logged_on() {
				return if now.duration_since(d.created) > LOGON_TIMEOUT {
					Some(Err("game server never logged on to Steam".to_string()))
				} else {
					None
				};
			}
			if !s.download_item(d.id) {
				return Some(Err("Steam refused DownloadItem (invalid id, private item or anonymous login restrictions)".to_string()));
			}
			d.phase = Phase::Requested;
			d.requested = now;
			d.progress_at = now;
			None
		}
		Phase::Requested => {
			let s = match steam::connect() {
				Ok(s) => s,
				Err(e) => return Some(Err(e)),
			};
			let state = s.item_state(d.id);
			if state != 0 {
				d.seen_state = true;
			}
			let busy = steam::ITEM_STATE_NEEDS_UPDATE | steam::ITEM_STATE_DOWNLOADING | steam::ITEM_STATE_DOWNLOAD_PENDING;
			if state & steam::ITEM_STATE_INSTALLED != 0 && state & busy == 0 {
				let Some(info) = s.install_info(d.id) else {
					return Some(Err("item installed but Steam returned no install folder".to_string()));
				};
				if let Some(path) = workshop::cached(d.id, info.timestamp) {
					return Some(Ok(path));
				}
				if !workshop::slot_available() {
					d.progress_at = now;
					return None;
				}
				d.phase = Phase::Extracting(workshop::Extraction::spawn(d.id, info.folder, info.timestamp));
				return None;
			}
			if let Some((done, _total)) = s.download_progress(d.id) {
				if done > d.progress {
					d.progress = done;
					d.progress_at = now;
				}
			}
			if !d.seen_state && now.duration_since(d.requested) > START_TIMEOUT {
				return Some(Err("Steam never started the download (item missing or not a Garry's Mod addon)".to_string()));
			}
			if now.duration_since(d.progress_at) > STALL_TIMEOUT {
				return Some(Err("download stalled".to_string()));
			}
			None
		}
		Phase::Extracting(job) => match job.poll() {
			workshop::Poll::Pending => None,
			workshop::Poll::Done(r) => Some(r),
		},
	}
}

fn step_query(q: &mut Query) -> Option<Result<Box<QueryInfo>, i32>> {
	let now = Instant::now();
	let expired = now.duration_since(q.created) > QUERY_TIMEOUT;
	let s = match steam::connect() {
		Ok(s) => s,
		Err(_) => return if expired { Some(Err(-1)) } else { None },
	};
	match q.phase {
		QueryPhase::Waiting => {
			if !s.logged_on() {
				return if expired { Some(Err(-4)) } else { None };
			}
			match s.start_details_query(q.id) {
				Ok((handle, call)) => {
					q.phase = QueryPhase::Sent { handle, call };
					None
				}
				Err(code) => Some(Err(code)),
			}
		}
		QueryPhase::Sent { handle, call } => {
			let finish = |r: Result<Box<QueryInfo>, i32>| {
				s.release_query(handle);
				Some(r)
			};
			match s.call_finished(call) {
				None => {
					if expired {
						finish(Err(-2))
					} else {
						None
					}
				}
				Some(false) => finish(Err(-2)),
				Some(true) => {
					let Some(done) = s.query_completed(call) else {
						return finish(Err(-2));
					};
					let result = done.result;
					let returned = done.num_results;
					if result != 1 {
						return finish(Err(result));
					}
					if returned != 1 {
						return finish(Err(-3));
					}
					let Some(details) = s.query_details(handle) else {
						return finish(Err(-3));
					};
					let fid = details.published_file_id;
					let item_result = details.result;
					if item_result != 1 {
						return finish(Err(item_result));
					}
					if fid == 0 {
						return finish(Err(-5));
					}
					if fid != q.id {
						return finish(Err(-6));
					}
					let kids = details.num_children;
					let children = s.query_children(handle, kids);
					finish(Ok(Box::new(QueryInfo { details, children })))
				}
			}
		}
	}
}

fn cstr_bytes(buf: &[u8]) -> &[u8] {
	let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
	&buf[..end]
}

fn push_query_table(lua: Lua, id: u64, info: &Result<Box<QueryInfo>, i32>) {
	lua.new_table(0, 24);
	lua.push_str(&id.to_string());
	lua.raw_set_field(-2, "id");
	match info {
		Err(code) => {
			lua.push_number(*code as f64);
			lua.raw_set_field(-2, "error");
		}
		Ok(q) => {
			let d = &q.details;
			let title = d.title;
			let description = d.description;
			let tags = d.tags;
			let url = d.url;
			let file_name = d.file_name;
			let owner = d.owner;
			let preview = d.preview_file;
			let file = d.file;
			let file_size = d.file_size;
			let total_size = d.total_files_size;
			let up = d.votes_up;
			let down = d.votes_down;

			lua.push_bytes(cstr_bytes(&title));
			lua.raw_set_field(-2, "title");
			lua.push_bytes(cstr_bytes(&description));
			lua.raw_set_field(-2, "description");
			lua.push_str(&owner.to_string());
			lua.raw_set_field(-2, "owner");
			lua.push_str(&preview.to_string());
			lua.raw_set_field(-2, "previewid");
			lua.push_str(&file.to_string());
			lua.raw_set_field(-2, "fileid");
			lua.push_bytes(cstr_bytes(&tags));
			lua.raw_set_field(-2, "tags");
			lua.push_bytes(cstr_bytes(&file_name));
			lua.raw_set_field(-2, "filename");
			lua.push_bool(d.banned);
			lua.raw_set_field(-2, "banned");
			lua.push_bool(d.accepted);
			lua.raw_set_field(-2, "accepted");
			lua.push_number(d.time_created as f64);
			lua.raw_set_field(-2, "created");
			lua.push_number(d.time_updated as f64);
			lua.raw_set_field(-2, "updated");
			let size = if total_size > 0 { total_size as f64 } else { (file_size.max(0)) as f64 };
			lua.push_number(size);
			lua.raw_set_field(-2, "size");
			lua.push_bytes(cstr_bytes(&url));
			lua.raw_set_field(-2, "previewurl");
			lua.push_number(d.preview_file_size.max(0) as f64);
			lua.raw_set_field(-2, "previewsize");
			lua.push_number(up as f64);
			lua.raw_set_field(-2, "up");
			lua.push_number(down as f64);
			lua.raw_set_field(-2, "down");
			lua.push_number(up as f64 + down as f64);
			lua.raw_set_field(-2, "total");
			lua.push_number(d.score as f64);
			lua.raw_set_field(-2, "score");
			lua.push_number(d.file_type as f64);
			lua.raw_set_field(-2, "filetype");
			lua.push_number(d.creator_app_id as f64);
			lua.raw_set_field(-2, "creator");
			lua.push_number(d.consumer_app_id as f64);
			lua.raw_set_field(-2, "consumer");
			lua.push_number(d.visibility as f64);
			lua.raw_set_field(-2, "visibility");
			lua.new_table(q.children.len() as c_int, 0);
			for (i, child) in q.children.iter().enumerate() {
				lua.push_str(&child.to_string());
				lua.raw_set_index(-2, (i + 1) as c_int);
			}
			lua.raw_set_field(-2, "children");
		}
	}
}

fn close_file(lua: Lua, file_ref: c_int) {
	let top = lua.top();
	lua.get_global("FindMetaTable");
	if lua.type_of(-1) == lua::TFUNCTION {
		lua.push_str("File");
		if lua.pcall(1, 1).is_ok() && lua.type_of(-1) == lua::TTABLE {
			lua.raw_get_field(-1, "Close");
			if lua.type_of(-1) == lua::TFUNCTION {
				lua.push_reference(file_ref);
				if lua.type_of(-1) == TUSERDATA {
					let _ = lua.pcall(1, 0);
				}
			}
		}
	}
	lua.set_top(top);
	lua.unreference(file_ref);
}

fn deliver_download(lua: Lua, callbacks: Vec<c_int>, result: Result<String, String>, id: u64) {
	if let Err(e) = &result {
		if id != 0 {
			log(lua, &format!("download of {} failed: {}", id, e));
		}
	}
	for cb in callbacks {
		let top = lua.top();
		lua.push_reference(cb);
		lua.unreference(cb);
		if lua.type_of(-1) != lua::TFUNCTION {
			lua.set_top(top);
			continue;
		}
		let mut file_ref = lua::NOREF;
		match &result {
			Ok(path) => {
				lua.push_str(path);
				let fn_top = lua.top();
				lua.get_global("file");
				let mut have_file = false;
				if lua.type_of(-1) == lua::TTABLE {
					lua.raw_get_field(-1, "Open");
					if lua.type_of(-1) == lua::TFUNCTION {
						lua.push_str(path);
						lua.push_str("rb");
						lua.push_str("GAME");
						if lua.pcall(3, 1).is_ok() && lua.type_of(-1) == TUSERDATA {
							lua.push_value(-1);
							file_ref = lua.reference();
							have_file = true;
						}
					}
				}
				lua.set_top(fn_top);
				if have_file {
					lua.push_reference(file_ref);
				} else {
					lua.push_nil();
				}
			}
			Err(_) => {
				lua.push_nil();
				lua.push_nil();
			}
		}
		if let Err(e) = lua.pcall(2, 0) {
			report_error(lua, &format!("DownloadUGC callback error: {}", e));
		}
		lua.set_top(top);
		if file_ref != lua::NOREF {
			close_file(lua, file_ref);
		}
	}
}

fn deliver_query(lua: Lua, callback: c_int, id: u64, info: Result<Box<QueryInfo>, i32>) {
	let top = lua.top();
	lua.push_reference(callback);
	lua.unreference(callback);
	if lua.type_of(-1) != lua::TFUNCTION {
		lua.set_top(top);
		return;
	}
	push_query_table(lua, id, &info);
	if let Err(e) = lua.pcall(1, 0) {
		report_error(lua, &format!("FileInfo callback error: {}", e));
	}
	lua.set_top(top);
}

unsafe extern "C" fn poll(state: State) -> c_int {
	let lua = Lua(state);
	let _ = catch_unwind(AssertUnwindSafe(|| {
		let mut done = with_module(|m| std::mem::take(&mut m.finished));
		with_module(|m| {
			let mut i = 0;
			while i < m.downloads.len() {
				if let Some(result) = step_download(&mut m.downloads[i]) {
					let d = m.downloads.remove(i);
					done.push(Finished::Download { callbacks: d.callbacks, result, id: d.id });
				} else {
					i += 1;
				}
			}
			let mut i = 0;
			while i < m.queries.len() {
				if let Some(info) = step_query(&mut m.queries[i]) {
					let q = m.queries.remove(i);
					done.push(Finished::Query { callback: q.callback, id: q.id, info });
				} else {
					i += 1;
				}
			}
		});
		for f in done {
			match f {
				Finished::Download { callbacks, result, id } => deliver_download(lua, callbacks, result, id),
				Finished::Query { callback, id, info } => deliver_query(lua, callback, id, info),
			}
		}
		let idle = with_module(|m| m.downloads.is_empty() && m.queries.is_empty() && m.finished.is_empty());
		if idle {
			stop_timer(lua);
		}
	}));
	0
}

#[no_mangle]
pub unsafe extern "C" fn gmod13_open(state: State) -> c_int {
	let result = catch_unwind(AssertUnwindSafe(|| {
		if let Err(e) = lua::init() {
			eprintln!("[gmsv_workshop] {}", e);
			return;
		}
		let lua = Lua(state);
		with_module(|m| *m = Module::default());

		let top = lua.top();
		lua.get_global("steamworks");
		if lua.type_of(-1) != lua::TTABLE {
			lua.pop(1);
			lua.new_table(0, 4);
			lua.push_value(-1);
			lua.raw_set_field(lua::GLOBALSINDEX, "steamworks");
		}

		let _ = std::thread::Builder::new().name("gmsv_workshop_prune".to_string()).spawn(|| {
			let _ = catch_unwind(workshop::prune_cache);
		});

		lua.push_str(VERSION);
		lua.raw_set_field(-2, "gmsv_workshop");
		lua.push_function(status);
		lua.raw_set_field(-2, "gmsv_workshop_status");

		match steam::fns() {
			Ok(f) => {
				lua.push_function(download_ugc);
				lua.raw_set_field(-2, "DownloadUGC");
				lua.push_function(file_info);
				lua.raw_set_field(-2, "FileInfo");
				log(lua, &format!("v{} loaded ({})", VERSION, f.versions));
			}
			Err(e) => {
				report_error(lua, &format!("v{} cannot use Steam: {} - steamworks.DownloadUGC NOT installed", VERSION, e));
			}
		}
		lua.set_top(top);
	}));
	if result.is_err() {
		eprintln!("[gmsv_workshop] panic during gmod13_open");
	}
	0
}

#[no_mangle]
pub unsafe extern "C" fn gmod13_close(_state: State) -> c_int {
	let _ = catch_unwind(AssertUnwindSafe(|| {
		with_module(|m| *m = Module::default());
	}));
	0
}
