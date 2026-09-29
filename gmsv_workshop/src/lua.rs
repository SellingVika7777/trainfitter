// Trainfitter - lua.rs
// Made by SellingVika

use crate::dylib::{self, Library};
use std::ffi::{c_char, c_int, c_void};
use std::sync::OnceLock;

pub type State = *mut c_void;
pub type CFunction = unsafe extern "C" fn(State) -> c_int;

pub const REGISTRYINDEX: c_int = -10000;
pub const GLOBALSINDEX: c_int = -10002;

pub const TNUMBER: c_int = 3;
pub const TSTRING: c_int = 4;
pub const TTABLE: c_int = 5;
pub const TFUNCTION: c_int = 6;

pub const NOREF: c_int = -2;

pub struct Api {
	settop: unsafe extern "C" fn(State, c_int),
	gettop: unsafe extern "C" fn(State) -> c_int,
	pushvalue: unsafe extern "C" fn(State, c_int),
	insert: unsafe extern "C" fn(State, c_int),
	type_: unsafe extern "C" fn(State, c_int) -> c_int,
	tolstring: unsafe extern "C" fn(State, c_int, *mut usize) -> *const c_char,
	pushnil: unsafe extern "C" fn(State),
	pushnumber: unsafe extern "C" fn(State, f64),
	pushlstring: unsafe extern "C" fn(State, *const c_char, usize),
	pushboolean: unsafe extern "C" fn(State, c_int),
	pushcclosure: unsafe extern "C" fn(State, CFunction, c_int),
	createtable: unsafe extern "C" fn(State, c_int, c_int),
	rawget: unsafe extern "C" fn(State, c_int),
	rawset: unsafe extern "C" fn(State, c_int),
	rawgeti: unsafe extern "C" fn(State, c_int, c_int),
	rawseti: unsafe extern "C" fn(State, c_int, c_int),
	pcall: unsafe extern "C" fn(State, c_int, c_int, c_int) -> c_int,
	lref: unsafe extern "C" fn(State, c_int) -> c_int,
	lunref: unsafe extern "C" fn(State, c_int, c_int),
}

static API: OnceLock<Api> = OnceLock::new();

fn lua_shared() -> Option<Library> {
	#[cfg(windows)]
	let names: &[&str] = &["lua_shared.dll"];
	#[cfg(unix)]
	let names: &[&str] = &["lua_shared_srv.so", "lua_shared.so"];

	#[cfg(all(windows, target_pointer_width = "64"))]
	let paths: &[&str] = &["garrysmod/bin/win64/lua_shared.dll", "bin/win64/lua_shared.dll"];
	#[cfg(all(windows, target_pointer_width = "32"))]
	let paths: &[&str] = &["garrysmod/bin/lua_shared.dll", "bin/lua_shared.dll"];
	#[cfg(all(unix, target_pointer_width = "64"))]
	let paths: &[&str] = &["bin/linux64/lua_shared.so", "bin/linux64/lua_shared_srv.so"];
	#[cfg(all(unix, target_pointer_width = "32"))]
	let paths: &[&str] = &["garrysmod/bin/lua_shared_srv.so", "bin/linux32/lua_shared.so", "garrysmod/bin/lua_shared.so", "bin/lua_shared_srv.so"];

	let lib = dylib::find_loaded(names).or_else(|| dylib::open_paths(paths, false))?;
	if lib.has("lua_pcall") {
		Some(lib)
	} else {
		None
	}
}

pub fn init() -> Result<(), String> {
	if API.get().is_some() {
		return Ok(());
	}
	let lib = lua_shared().ok_or_else(|| "lua_shared library not found in process".to_string())?;

	macro_rules! sym {
		($name:literal) => {{
			let p = lib.symbol($name);
			if p.is_null() {
				return Err(format!("lua_shared is missing {}", $name));
			}
			unsafe { std::mem::transmute(p) }
		}};
	}

	let api = Api {
		settop: sym!("lua_settop"),
		gettop: sym!("lua_gettop"),
		pushvalue: sym!("lua_pushvalue"),
		insert: sym!("lua_insert"),
		type_: sym!("lua_type"),
		tolstring: sym!("lua_tolstring"),
		pushnil: sym!("lua_pushnil"),
		pushnumber: sym!("lua_pushnumber"),
		pushlstring: sym!("lua_pushlstring"),
		pushboolean: sym!("lua_pushboolean"),
		pushcclosure: sym!("lua_pushcclosure"),
		createtable: sym!("lua_createtable"),
		rawget: sym!("lua_rawget"),
		rawset: sym!("lua_rawset"),
		rawgeti: sym!("lua_rawgeti"),
		rawseti: sym!("lua_rawseti"),
		pcall: sym!("lua_pcall"),
		lref: sym!("luaL_ref"),
		lunref: sym!("luaL_unref"),
	};
	let _ = API.set(api);
	Ok(())
}

fn api() -> &'static Api {
	API.get().expect("lua api not initialised")
}

#[derive(Clone, Copy)]
pub struct Lua(pub State);

impl Lua {
	pub fn top(&self) -> c_int {
		unsafe { (api().gettop)(self.0) }
	}

	pub fn set_top(&self, n: c_int) {
		unsafe { (api().settop)(self.0, n) }
	}

	pub fn pop(&self, n: c_int) {
		self.set_top(-n - 1)
	}

	pub fn push_value(&self, idx: c_int) {
		unsafe { (api().pushvalue)(self.0, idx) }
	}

	pub fn type_of(&self, idx: c_int) -> c_int {
		unsafe { (api().type_)(self.0, idx) }
	}

	pub fn to_string(&self, idx: c_int) -> Option<String> {
		let t = self.type_of(idx);
		if t != TSTRING && t != TNUMBER {
			return None;
		}
		let mut len = 0usize;
		let ptr = unsafe { (api().tolstring)(self.0, idx, &mut len) };
		if ptr.is_null() {
			return None;
		}
		let bytes = unsafe { std::slice::from_raw_parts(ptr as *const u8, len) };
		Some(String::from_utf8_lossy(bytes).into_owned())
	}

	pub fn push_nil(&self) {
		unsafe { (api().pushnil)(self.0) }
	}

	pub fn push_number(&self, n: f64) {
		unsafe { (api().pushnumber)(self.0, n) }
	}

	pub fn push_bool(&self, b: bool) {
		unsafe { (api().pushboolean)(self.0, b as c_int) }
	}

	pub fn push_bytes(&self, b: &[u8]) {
		unsafe { (api().pushlstring)(self.0, b.as_ptr() as *const c_char, b.len()) }
	}

	pub fn push_str(&self, s: &str) {
		self.push_bytes(s.as_bytes())
	}

	pub fn push_function(&self, f: CFunction) {
		unsafe { (api().pushcclosure)(self.0, f, 0) }
	}

	pub fn new_table(&self, narr: c_int, nrec: c_int) {
		unsafe { (api().createtable)(self.0, narr, nrec) }
	}

	pub fn raw_get_field(&self, idx: c_int, key: &str) {
		let abs = self.abs(idx);
		self.push_str(key);
		unsafe { (api().rawget)(self.0, abs) }
	}

	pub fn raw_set_field(&self, idx: c_int, key: &str) {
		let abs = self.abs(idx);
		self.push_str(key);
		unsafe {
			(api().insert)(self.0, -2);
			(api().rawset)(self.0, abs)
		}
	}

	pub fn raw_set_index(&self, idx: c_int, n: c_int) {
		let abs = self.abs(idx);
		unsafe { (api().rawseti)(self.0, abs, n) }
	}

	pub fn abs(&self, idx: c_int) -> c_int {
		if idx > 0 || idx <= REGISTRYINDEX {
			idx
		} else {
			self.top() + idx + 1
		}
	}

	pub fn get_global(&self, key: &str) {
		self.raw_get_field(GLOBALSINDEX, key)
	}

	pub fn reference(&self) -> c_int {
		unsafe { (api().lref)(self.0, REGISTRYINDEX) }
	}

	pub fn unreference(&self, r: c_int) {
		if r != NOREF {
			unsafe { (api().lunref)(self.0, REGISTRYINDEX, r) }
		}
	}

	pub fn push_reference(&self, r: c_int) {
		unsafe { (api().rawgeti)(self.0, REGISTRYINDEX, r) }
	}

	pub fn pcall(&self, nargs: c_int, nresults: c_int) -> Result<(), String> {
		let rc = unsafe { (api().pcall)(self.0, nargs, nresults, 0) };
		if rc == 0 {
			Ok(())
		} else {
			let msg = self.to_string(-1).unwrap_or_else(|| "unknown error".to_string());
			self.pop(1);
			Err(msg)
		}
	}
}
