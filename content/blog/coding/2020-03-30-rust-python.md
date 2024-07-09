---
.title = "Extending Python With Rust",
.date = @date("2020-07-06"),
.author = "Lewis Gaul",
.layout = "blog_post.html",
.tags = ["python", "rust"],
---

People think Python is slow. In actual fact, if you compare to other popular programming languages... it's true! What some people don't understand, is the difference between *relative speed* and *being fast enough*.

If there's a genuine reason to want your code to go faster, some of the options available include: improving the Python code, rewriting in a different language, or just writing an extension in another language to optimise the slow bit. Let's explore this third option - it allows writing most of the code in Python while still giving huge room for improvement in performance-critical parts.


## Anyone Know A Good Fast Language?

Since Python's conception, the canonical 'fast' language has been C: low-level, simple, and standing the test of time. Sure, it doesn't come with common modern-language features such as a strong type system, thread safety or a convenient toolchain providing easy access to third-party libraries, it has a questionable macro system, and it's known for its many undefined behaviours... But the reference implementation of Python itself is written using C - surely in the case of writing an extension for Python, C is the obvious choice?

How would you rank the top 5 fastest programming languages? Perhaps some of the following:

 - C - the obvious choice (I claim)
 - C++ - heavyweight version of C
 - Java - better for long-running processes since it uses JIT compilation; requires the JVM
 - Go - a relatively new language (introduced in 2009) flaunting a new concurrency model
 - Rust - one year younger than Go, with a focus on performance and safety
 - Haskell - if functional programming is your thing

I haven't given much thought to extending Python with Java, Go or Haskell. I hadn't written any Rust before, but with comparable performance to C and all the shiny new charactistics and features of a modern language, it seemed worth exploring...


## Python, Meet Rust! ...Who?

So we want to write a Python extension in Rust to optimise the performance critical logic of our program. But how do we break the ice and get them chatting to one another?


### What Language Can Python Speak?

As we know, Python has known how to talk to C for a long time in a variety of ways:

 - Write a dedicated [Python extension in C](https://docs.python.org/3/extending/extending.html) using the CPython C API.
 - Use [ctypes](https://docs.python.org/3/library/ctypes.html) - a stdlib module providing a mechanism to interact with C libraries and call C functions.
 - Use [cython](https://cython.org/) - a hybrid of C and Python, compiling to C code.
 - Use [cffi](https://cffi.readthedocs.io/en/latest/index.html) - a 'C foreign function interface' for Python, allowing interaction with C code from Python.

I've used cython before, and it's impressive what it can do, but it feels like you're learning a whole new language. I find the ctypes and cffi options appealing because they allow making use of a C library without a big fuss.

This allows separating the problem cleanly into two parts: make the library, and use the library. If I want to use the library again, maybe from another language that can operate with the C ABI, then I can do so! If I want to rewrite the library, maybe from a different language that can output in the C ABI format, then I can do so!


### Was Rust Invited to the Party?

Rust natively supports linking against C libraries and calling their functions directly, as well as supporting compiling to a library in C ABI format. This is essential to allow gradual integration of Rust into a C/C++ project, which is the only viable path to eventual migration for any reasonably-sized project.

Rust doesn't need an invitation; it masquerades so well as C that it's impossible to see through its disguise. In fact, Rust will happily steal one of C's outfits to make absolutely sure not to get caught!

...By which I obviously mean Rust is capable of reading C header files and implementing functions that are declared as part of the public C API. This is part of the elegance! A client of the library gets a normal C header file and a library implementing the API - there is no indication of it being implemented in Rust, and it can be used from Python, C, C++...


## Show Me The Money

As previously mentioned, the implementation can be split into two entirely distinct parts: making the library in Rust, and using the library in Python. Both use C header files as the API definition.

This guide aims to give an explanation and references that should be sufficient to get up and running with Python-Rust interoperation. I'm not going to go into details on bits that are covered elsewhere - I'll just point to a separate set of instructions.

In this post I'll use a simple toy example - an extension of this example with some more complexity is available at <https://github.com/LewisGaul/python-rust-example>.


### Defining The API

Given the purpose of this exercise is to pick out a piece of logic and make it fast, it makes sense to start by defining the API and giving some thought to the details of its responsibility.

I'll be using this basic example:

```c
// filename: api.h

#include <stdint.h>

// Function to calculate pi correct to n decimal places.
float calc_pi(uint8_t n);
```


### Getting Rusty

Let's start with the more interesting half!

Step zero: get set up with Rust. This is boring (but necessary!) - see <https://www.rust-lang.org/learn/get-started>.

I'd recommend using the following directory structure. The contents of `api.h` were given in the previous section, and the other files are explained below.

```
rust-example/
├── Cargo.toml
├── build.rs
├── include
│   └── api.h
└── src
    └── lib.rs
```

Once you've filled in the files as explained below, you should be able to simply run `cargo build` and wait to see "Finished"! You should find a `target/` directory is created in `rust-example/`, where you should find:

 * `target/debug/libpi.so` - The built C library!
 * `target/debug/build/example-pi-<checksum>/out/bindings.rs` - The generated Rust bindings module, which may be of interest.


#### Cargo.toml

This is the manifest file for the project used by [Cargo](https://doc.rust-lang.org/cargo/), the Rust package manager.

Copy the following into yours:

```toml
# filename: Cargo.toml

[package]
name = "example-pi"
version = "0.1.0"
authors = ["John Smith <john.smith@gmail.com>"]

[lib]
name = "pi"              # Name of the library
crate-type = ["cdylib"]  # Indicating we're making a C dynamic library

[dependencies]
# (runtime dependencies would go here)

[build-dependencies]
bindgen = "0.53.2"       # We will be using this in build.rs
```


#### build.rs

This is our first Rust file! This is a special file that is automatically compiled into an executable and run *after* installing dependencies, but *before* compiling the main source code when building with Cargo (see [here](https://doc.rust-lang.org/cargo/reference/build-scripts.html)). In this case we use it to read the C header file and convert into Rust.

The contents of the file should be as follows (this is pretty much just boilerplate, although you may want to customise some of the options):

```rust
// filename: build.rs

extern crate bindgen;

use std::env;
use std::path::PathBuf;

fn main() {
    // Tell cargo to invalidate the built crate whenever the wrapper changes.
    println!("cargo:rerun-if-changed=include/api.h");

    // The bindgen::Builder is the main entry point to bindgen, and lets you
    // build up options for the resulting bindings.
    let bindings = bindgen::Builder::default()
        // The input header we would like to generate bindings for.
        .header("include/api.h")
        // Tell cargo to invalidate the built crate whenever any of the
        // included header files changed.
        .parse_callbacks(Box::new(bindgen::CargoCallbacks))
        // Control enum name mangling.
        .prepend_enum_name(false)
        // Finish the builder and generate the bindings.
        .generate()
        // Unwrap the result and panic on failure.
        .expect("Unable to generate bindings");

    // Write the bindings to the $OUT_DIR/bindings.rs file.
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");
}
```


#### src/lib.rs

Finally, this is where we put our implementation of the API in the header file. This is also a special filename which is used by Cargo as the main file for generating a library (just like `main.rs` is used for creating an executable by default, although this can be customised in `Cargo.toml`).

The file should look something like this:

```rust
// filename: lib.rs

// Include the generated API Rust bindings.
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]
#![allow(dead_code)]
include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

/// See api.h for the C API being implemented.
#[no_mangle]
pub unsafe extern "C" fn calc_pi(n: u8) -> f32 {
    calc_pi_impl(n)
}

/// Rust implementation of the 'calc_pi()' API.
fn calc_pi_impl(digits: u8) -> f32 {
    let pi: f32;
    // Some logic ...
    pi = 5.14 - 2.0;
    // Some logic ...
    pi
}
```

Let's talk through what's going on here!

Firstly, the block at the top of the file uses the `include!()` macro to include the contents of the Rust bindings file, as generated by `build.rs`. This works in a similar way to C's `#include` macro. The various `#![allow(...)]` lines are just there to silence warnings from the naming used in the conversion of C code to Rust.

The rest of the file is the implementation of the `calc_pi()` API function. There are a number of parts to understand here:

 * `#[no_mangle]` - don't mangle the function name with a namespace when creating the library (C compatibility)
 * `pub` - 'public', expose this function
 * `unsafe` - this code is unsafe because it's a C API!
 * `extern "C"` - expose as a C API

Also note the choice to minimise the code in the unsafe function - putting as much code as possible in regular Rust functions maximises the checks the Rust compiler can perform for you.


### Getting Pythony

Now we have a C library, `libpi.so`, which exposes the `calc_pi()` function defined in our header file `api.h`. The rest is just the same whichever C library you might want to interoperate with. I'm going to show how it can be done using `cffi`.

First, '`pip install cffi`' into your Python virtualenv. It is then as simple as the following:

```python
# filename: test_calc_pi.py

import pathlib
import subprocess
import cffi

RUST_PROJ_PATH = pathlib.Path("/path/to/rust/project/")
HEADER_PATH = RUST_PROJ_PATH / "include" / "api.h"
LIB_PATH = RUST_PROJ_PATH / "target" / "debug" / "libpi.so"

def _read_header(hdr):
    """Run the C preprocessor over a header file."""
    return subprocess.run(
        ["cc", "-E", hdr], stdout=subprocess.PIPE, universal_newlines=True
    ).stdout
    
ffi = cffi.FFI()                          # Initialise
ffi.cdef(_read_header(str(HEADER_PATH)))  # Read in the header file
lib = ffi.dlopen(str(LIB_PATH))           # Open the dynamic library
pi = lib.calc_pi(2)                       # Call the Rust function
print("Calculated pi to 2 decimal places:", pi)
```


## Conclusion

Once you have all this boilerplate in place, it seems this setup could provide a convenient way to replace bits of Python code with a much faster alternative implemntation, while still providing safety guarantees in the heart of the logic.

I'd be interested to hear any thoughts if anyone tries it out, and may create a follow-up post if I take it any further!
