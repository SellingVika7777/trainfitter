// Trainfitter - steam.rs
// Made by SellingVika

use crate::dylib::{self, Library};
use std::ffi::{c_char, c_int, c_void};
use std::sync::OnceLock;

pub type Handle = *mut c_void;

pub const ITEM_STATE_INSTALLED: u32 = 4;
pub const ITEM_STATE_NEEDS_UPDATE: u32 = 8;
pub const ITEM_STATE_DOWNLOADING: u32 = 16;
pub const ITEM_STATE_DOWNLOAD_PENDING: u32 = 32;

pub const QUERY_HANDLE_INVALID: u64 = u64::MAX;
pub const CALLBACK_UGC_QUERY_COMPLETED: c_int = 3401;

pub const TITLE_MAX: usize = 129;
pub const DESCRIPTION_MAX: usize = 8000;
pub const TAGS_MAX: usize = 1025;
pub const FILENAME_MAX: usize = 260;
pub const URL_MAX: usize = 256;

#[cfg_attr(windows, repr(C))]
#[cfg_attr(unix, repr(C, packed(4)))]
#[derive(Clone, Copy)]
pub struct UgcDetails {
	pub published_file_id: u64,
	pub result: i32,
	pub file_type: i32,
	pub creator_app_id: u32,
	pub consumer_app_id: u32,
	pub title: [u8; TITLE_MAX],
	pub description: [u8; DESCRIPTION_MAX],
	pub owner: u64,
	pub time_created: u32,
	pub time_updated: u32,
	pub time_added: u32,
	pub visibility: i32,
	pub banned: bool,
	pub accepted: bool,
	pub tags_truncated: bool,
	pub tags: [u8; TAGS_MAX],
	pub file: u64,
	pub preview_file: u64,
	pub file_name: [u8; FILENAME_MAX],
	pub file_size: i32,
	pub preview_file_size: i32,
	pub url: [u8; URL_MAX],
	pub votes_up: u32,
	pub votes_down: u32,
	pub score: f32,
	pub num_children: u32,
	pub total_files_size: u64,
}

#[cfg_attr(windows, repr(C))]
#[cfg_attr(unix, repr(C, packed(4)))]
#[derive(Clone, Copy)]
pub struct UgcQueryCompleted {
	pub handle: u64,
	pub result: i32,
	pub num_results: u32,
	pub total_results: u32,
	pub cached: bool,
	pub next_cursor: [u8; URL_MAX],
}

pub struct Fns {
	accessor_server: unsafe extern "C" fn() -> Handle,
	accessor_ugc: unsafe extern "C" fn() -> Handle,
	accessor_utils: unsafe extern "C" fn() -> Handle,
	logged_on: unsafe extern "C" fn(Handle) -> bool,
	download_item: unsafe extern "C" fn(Handle, u64, bool) -> bool,
	item_state: unsafe extern "C" fn(Handle, u64) -> u32,
	install_info: unsafe extern "C" fn(Handle, u64, *mut u64, *mut c_char, u32, *mut u32) -> bool,
	download_info: unsafe extern "C" fn(Handle, u64, *mut u64, *mut u64) -> bool,
	suspend_downloads: unsafe extern "C" fn(Handle, bool),
	create_details_query: unsafe extern "C" fn(Handle, *mut u64, u32) -> u64,
	set_return_children: unsafe extern "C" fn(Handle, u64, bool) -> bool,
	set_return_long_description: unsafe extern "C" fn(Handle, u64, bool) -> bool,
	set_allow_cached: unsafe extern "C" fn(Handle, u64, u32) -> bool,
	send_query: unsafe extern "C" fn(Handle, u64) -> u64,
	query_result: unsafe extern "C" fn(Handle, u64, u32, *mut c_void) -> bool,
	query_children: unsafe extern "C" fn(Handle, u64, u32, *mut u64, u32) -> bool,
	release_query: unsafe extern "C" fn(Handle, u64) -> bool,
	call_completed: unsafe extern "C" fn(Handle, u64, *mut bool) -> bool,
	call_result: unsafe extern "C" fn(Handle, u64, *mut c_void, c_int, c_int, *mut bool) -> bool,
	pub versions: String,
}

static FNS: OnceLock<Result<Fns, String>> = OnceLock::new();

fn steam_api() -> Option<Library> {
	#[cfg(all(windows, target_pointer_width = "64"))]
	let names: &[&str] = &["steam_api64.dll"];
	#[cfg(all(windows, target_pointer_width = "32"))]
	let names: &[&str] = &["steam_api.dll"];
	#[cfg(unix)]
	let names: &[&str] = &["libsteam_api.so"];

	#[cfg(all(windows, target_pointer_width = "64"))]
	let paths: &[&str] = &["bin/win64/steam_api64.dll", "bin/steam_api64.dll"];
	#[cfg(all(windows, target_pointer_width = "32"))]
	let paths: &[&str] = &["bin/steam_api.dll", "garrysmod/bin/steam_api.dll"];
	#[cfg(all(unix, target_pointer_width = "64"))]
	let paths: &[&str] = &["bin/linux64/libsteam_api.so", "bin/libsteam_api.so"];
	#[cfg(all(unix, target_pointer_width = "32"))]
	let paths: &[&str] = &["bin/libsteam_api.so", "bin/linux32/libsteam_api.so", "garrysmod/bin/libsteam_api.so"];

	dylib::find_loaded(names).or_else(|| dylib::open_paths(paths, false))
}

fn versioned(lib: &Library, prefix: &str) -> Option<(*mut c_void, String)> {
	for v in (1..=64).rev() {
		let name = format!("{}{:03}", prefix, v);
		let p = lib.symbol(&name);
		if !p.is_null() {
			return Some((p, name));
		}
	}
	None
}

fn resolve() -> Result<Fns, String> {
	let lib = steam_api().ok_or_else(|| "steam_api library is not loaded in this process".to_string())?;

	let (server, server_name) = versioned(&lib, "SteamAPI_SteamGameServer_v").ok_or("no SteamAPI_SteamGameServer_vXXX export")?;
	let (ugc, ugc_name) = versioned(&lib, "SteamAPI_SteamGameServerUGC_v").ok_or("no SteamAPI_SteamGameServerUGC_vXXX export")?;
	let (utils, utils_name) = versioned(&lib, "SteamAPI_SteamGameServerUtils_v").ok_or("no SteamAPI_SteamGameServerUtils_vXXX export")?;

	macro_rules! sym {
		($name:literal) => {{
			let p = lib.symbol($name);
			if p.is_null() {
				return Err(format!("steam_api is missing {}", $name));
			}
			unsafe { std::mem::transmute(p) }
		}};
	}

	Ok(Fns {
		accessor_server: unsafe { std::mem::transmute(server) },
		accessor_ugc: unsafe { std::mem::transmute(ugc) },
		accessor_utils: unsafe { std::mem::transmute(utils) },
		logged_on: sym!("SteamAPI_ISteamGameServer_BLoggedOn"),
		download_item: sym!("SteamAPI_ISteamUGC_DownloadItem"),
		item_state: sym!("SteamAPI_ISteamUGC_GetItemState"),
		install_info: sym!("SteamAPI_ISteamUGC_GetItemInstallInfo"),
		download_info: sym!("SteamAPI_ISteamUGC_GetItemDownloadInfo"),
		suspend_downloads: sym!("SteamAPI_ISteamUGC_SuspendDownloads"),
		create_details_query: sym!("SteamAPI_ISteamUGC_CreateQueryUGCDetailsRequest"),
		set_return_children: sym!("SteamAPI_ISteamUGC_SetReturnChildren"),
		set_return_long_description: sym!("SteamAPI_ISteamUGC_SetReturnLongDescription"),
		set_allow_cached: sym!("SteamAPI_ISteamUGC_SetAllowCachedResponse"),
		send_query: sym!("SteamAPI_ISteamUGC_SendQueryUGCRequest"),
		query_result: sym!("SteamAPI_ISteamUGC_GetQueryUGCResult"),
		query_children: sym!("SteamAPI_ISteamUGC_GetQueryUGCChildren"),
		release_query: sym!("SteamAPI_ISteamUGC_ReleaseQueryUGCRequest"),
		call_completed: sym!("SteamAPI_ISteamUtils_IsAPICallCompleted"),
		call_result: sym!("SteamAPI_ISteamUtils_GetAPICallResult"),
		versions: format!("{}, {}, {}", server_name, ugc_name, utils_name),
	})
}

pub fn fns() -> Result<&'static Fns, String> {
	match FNS.get_or_init(resolve) {
		Ok(f) => Ok(f),
		Err(e) => Err(e.clone()),
	}
}

pub struct Steam {
	f: &'static Fns,
	server: Handle,
	ugc: Handle,
	utils: Handle,
}

pub fn connect() -> Result<Steam, String> {
	let f = fns()?;
	let server = unsafe { (f.accessor_server)() };
	let ugc = unsafe { (f.accessor_ugc)() };
	let utils = unsafe { (f.accessor_utils)() };
	if server.is_null() || ugc.is_null() || utils.is_null() {
		return Err("Steam game server interfaces are not initialised yet".to_string());
	}
	Ok(Steam { f, server, ugc, utils })
}

pub struct InstallInfo {
	pub folder: String,
	pub timestamp: u32,
}

impl Steam {
	pub fn logged_on(&self) -> bool {
		unsafe { (self.f.logged_on)(self.server) }
	}

	pub fn download_item(&self, id: u64) -> bool {
		unsafe {
			(self.f.suspend_downloads)(self.ugc, false);
			(self.f.download_item)(self.ugc, id, true)
		}
	}

	pub fn item_state(&self, id: u64) -> u32 {
		unsafe { (self.f.item_state)(self.ugc, id) }
	}

	pub fn install_info(&self, id: u64) -> Option<InstallInfo> {
		let mut size = 0u64;
		let mut stamp = 0u32;
		let mut buf = vec![0u8; 4096];
		let ok = unsafe { (self.f.install_info)(self.ugc, id, &mut size, buf.as_mut_ptr() as *mut c_char, buf.len() as u32, &mut stamp) };
		if !ok {
			return None;
		}
		let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
		let folder = String::from_utf8_lossy(&buf[..end]).into_owned();
		if folder.is_empty() {
			return None;
		}
		let _ = size;
		Some(InstallInfo { folder, timestamp: stamp })
	}

	pub fn download_progress(&self, id: u64) -> Option<(u64, u64)> {
		let mut done = 0u64;
		let mut total = 0u64;
		let ok = unsafe { (self.f.download_info)(self.ugc, id, &mut done, &mut total) };
		if ok {
			Some((done, total))
		} else {
			None
		}
	}

	pub fn start_details_query(&self, id: u64) -> Result<(u64, u64), i32> {
		let mut ids = [id];
		let handle = unsafe { (self.f.create_details_query)(self.ugc, ids.as_mut_ptr(), 1) };
		if handle == QUERY_HANDLE_INVALID {
			return Err(-1);
		}
		unsafe {
			(self.f.set_return_children)(self.ugc, handle, true);
			(self.f.set_return_long_description)(self.ugc, handle, true);
			(self.f.set_allow_cached)(self.ugc, handle, 60);
		}
		let call = unsafe { (self.f.send_query)(self.ugc, handle) };
		if call == 0 {
			self.release_query(handle);
			return Err(-2);
		}
		Ok((handle, call))
	}

	pub fn call_finished(&self, call: u64) -> Option<bool> {
		let mut failed = false;
		let done = unsafe { (self.f.call_completed)(self.utils, call, &mut failed) };
		if done {
			Some(!failed)
		} else {
			None
		}
	}

	pub fn query_completed(&self, call: u64) -> Option<UgcQueryCompleted> {
		let mut out = std::mem::MaybeUninit::<UgcQueryCompleted>::zeroed();
		let mut failed = false;
		let ok = unsafe {
			(self.f.call_result)(self.utils, call, out.as_mut_ptr() as *mut c_void, std::mem::size_of::<UgcQueryCompleted>() as c_int, CALLBACK_UGC_QUERY_COMPLETED, &mut failed)
		};
		if !ok || failed {
			return None;
		}
		Some(unsafe { out.assume_init() })
	}

	pub fn query_details(&self, handle: u64) -> Option<Box<UgcDetails>> {
		let size = std::mem::size_of::<UgcDetails>() + 16384;
		let mut buf = vec![0u64; size.div_ceil(8)];
		let ok = unsafe { (self.f.query_result)(self.ugc, handle, 0, buf.as_mut_ptr() as *mut c_void) };
		if !ok {
			return None;
		}
		let details = unsafe { std::ptr::read_unaligned(buf.as_ptr() as *const UgcDetails) };
		Some(Box::new(details))
	}

	pub fn query_children(&self, handle: u64, count: u32) -> Vec<u64> {
		if count == 0 {
			return Vec::new();
		}
		let count = count.min(4096);
		let mut out = vec![0u64; count as usize];
		let ok = unsafe { (self.f.query_children)(self.ugc, handle, 0, out.as_mut_ptr(), count) };
		if !ok {
			return Vec::new();
		}
		out.retain(|&id| id != 0);
		out
	}

	pub fn release_query(&self, handle: u64) {
		unsafe {
			(self.f.release_query)(self.ugc, handle);
		}
	}
}
