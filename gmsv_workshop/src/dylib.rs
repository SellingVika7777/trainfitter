// Trainfitter - dylib.rs
// Made by SellingVika

use std::ffi::{c_void, CString};

#[derive(Clone, Copy)]
pub struct Library(*mut c_void);

impl Library {
	pub fn symbol(&self, name: &str) -> *mut c_void {
		let Ok(cname) = CString::new(name) else {
			return std::ptr::null_mut();
		};
		unsafe { sys::symbol(self.0, &cname) }
	}

	pub fn has(&self, name: &str) -> bool {
		!self.symbol(name).is_null()
	}
}

pub fn find_loaded(names: &[&str]) -> Option<Library> {
	for name in names {
		let handle = unsafe { sys::open_loaded(name) };
		if !handle.is_null() {
			return Some(Library(handle));
		}
	}
	None
}

pub fn open_paths(paths: &[&str], allow_load: bool) -> Option<Library> {
	for path in paths {
		let handle = unsafe { sys::open_path(path, allow_load) };
		if !handle.is_null() {
			return Some(Library(handle));
		}
	}
	None
}

#[cfg(windows)]
mod sys {
	use std::ffi::{c_char, c_void, CStr};

	#[link(name = "kernel32")]
	extern "system" {
		fn GetModuleHandleW(name: *const u16) -> *mut c_void;
		fn LoadLibraryW(name: *const u16) -> *mut c_void;
		fn GetProcAddress(module: *mut c_void, name: *const c_char) -> *mut c_void;
	}

	fn wide(s: &str) -> Vec<u16> {
		s.encode_utf16().chain(std::iter::once(0)).collect()
	}

	pub unsafe fn open_loaded(name: &str) -> *mut c_void {
		let w = wide(name);
		GetModuleHandleW(w.as_ptr())
	}

	pub unsafe fn open_path(path: &str, allow_load: bool) -> *mut c_void {
		let w = wide(path);
		let handle = GetModuleHandleW(w.as_ptr());
		if !handle.is_null() {
			return handle;
		}
		if !allow_load || !std::path::Path::new(path).is_file() {
			return std::ptr::null_mut();
		}
		LoadLibraryW(w.as_ptr())
	}

	pub unsafe fn symbol(handle: *mut c_void, name: &CStr) -> *mut c_void {
		if handle.is_null() {
			return std::ptr::null_mut();
		}
		GetProcAddress(handle, name.as_ptr())
	}
}

#[cfg(unix)]
mod sys {
	use std::ffi::{c_char, c_int, c_void, CStr, CString};

	const RTLD_NOW: c_int = 2;
	const RTLD_NOLOAD: c_int = 4;

	#[link(name = "dl")]
	extern "C" {
		fn dlopen(name: *const c_char, flags: c_int) -> *mut c_void;
		fn dlsym(handle: *mut c_void, name: *const c_char) -> *mut c_void;
	}

	pub unsafe fn open_loaded(name: &str) -> *mut c_void {
		let Ok(c) = CString::new(name) else {
			return std::ptr::null_mut();
		};
		dlopen(c.as_ptr(), RTLD_NOW | RTLD_NOLOAD)
	}

	pub unsafe fn open_path(path: &str, allow_load: bool) -> *mut c_void {
		let full = match std::fs::canonicalize(path) {
			Ok(p) => p,
			Err(_) => return std::ptr::null_mut(),
		};
		let Some(s) = full.to_str() else {
			return std::ptr::null_mut();
		};
		let Ok(c) = CString::new(s) else {
			return std::ptr::null_mut();
		};
		let loaded = dlopen(c.as_ptr(), RTLD_NOW | RTLD_NOLOAD);
		if !loaded.is_null() || !allow_load {
			return loaded;
		}
		dlopen(c.as_ptr(), RTLD_NOW)
	}

	pub unsafe fn symbol(handle: *mut c_void, name: &CStr) -> *mut c_void {
		if handle.is_null() {
			return std::ptr::null_mut();
		}
		dlsym(handle, name.as_ptr())
	}
}
