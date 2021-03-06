---
title: First Contribution To Zig
layout: post
categories: [coding]
tags: [zig, open-source, language]
---


Recently one of the main things I've been intending to learn more about is the Zig programming language. I came across an issue tagged with 'contributor friendly' in the issue tracker that seemed approachable and decided I might as well try diving in!

<img src="/assets/img/zig-mascot-zero.svg" id="zig-zero" alt="Zig mascot Zero the Ziguana" width="200" height="200" />

For readers who would like a refresher on Zig I would recommend taking a look at the (recently revamped) website: <https://ziglang.org/>. Feel free to check out my [previous blog post about Zig](../../../01/10/trying-zig) too!

The issue that caught my interest was a recent regression in `zig fmt`, caused by a rewrite of the AST machinery that I'd been watching on streams presented by Andrew Kelley (the creator of Zig).

The issue: <https://github.com/ziglang/zig/issues/8088>  
My PR: <https://github.com/ziglang/zig/pull/8127>


## Setup

I started with the [CONTRIBUTING.md](https://github.com/ziglang/zig/blob/master/CONTRIBUTING.md) page, following the link under "Editing Source Code" to [Building Zig From Source](https://github.com/ziglang/zig/wiki/Building-Zig-From-Source). Surprisingly I'm now on my way to being 4/4 for following the contribution suggestions: start a project using Zig ([zigominoes](https://github.com/LewisGaul/zigominoes) and [zig-nestedtext](https://github.com/LewisGaul/zig-nestedtext)); spread the word (these blog posts, word of mouth); finding contributor friendly issues; editing source code.

The main pain point I had was installing all required LLVM/Clang/LLD libraries - presumably it's difficult to give generic advice as this varies by OS? On Ubuntu20.04 I initially missed the apt packages `libclang-11-dev` and `liblld-11-dev`, although I'm not sure of the full minimal set of required dependencies.

The Zig build then succeeded without issue, following the basic steps below.

```bash
mkdir build/ && cd build/
cmake ..
make install
./zig -h  # It works!
```


## Development

### Finding the relevant code

The Zig codebase layout is reasonably easy to navigate, although it did take me a moment to find the code for the 'zig fmt' command ('format' and 'fmt' were the wrong things to be searching for). Thankfully, having ZLS set up with VSCode makes it much easier to find your bearings with 'go to definition'.

To illustrate how this can work:
 - I started my search in `src/main.zig`
 - I found `fmtPathFile()` (via `main()` -> `mainArgs()` -> `cmdFmt()` -> `fmtPath()`)
 - I found `tree.renderToArrayList()`, and the type of `tree` via the `std.zig.parse()` call above it
 - `std.ast.Tree.renderToArrayList()` does `@import("./render.zig")`, at which point I'd found the correct module

I was also slightly surprised to find the corresponding test alongside the source file (`lib/std/zig/parser_test.zig`) rather than in the `test/` directory - I'm still not sure why this is the case.


### Development cycle

I was mostly running '`make install`' to build after making changes, although this was a bit slow for iterative development. Someone on IRC suggested it should be fine to just run '`./zig test ../lib/std/zig/parser_test.zig`' and that this would trigger `render.zig` to be rebuilt, but I'm not convinced this was always happening for me...

I found the easiest way to test `zig fmt` was to create an example Zig file mirroring the testcase I'd added (all of the below are expected to be unchanged by `zig fmt`):

```zig
test "for if" {
    for (a) |x| if (x) f(x);

    for (a) |x| if (x)
        f(x);

    for (a) |x| if (x) {
        f(x);
    };

    for (a) |x|
        if (x)
            f(x);

    for (a) |x|
        if (x) {
            f(x);
        };
}
```

I then ran `zig fmt` using the local `zig` executable and occasionally with my global executable to compare against behaviour of the latest release version (0.7.1).

```bash
./zig fmt --stdin < example.zig  # Development version
zig fmt --stdin < example.zig    # Version 0.7.1
```


### Debugging

I had my first go at using GDB for stepping through Zig code and was pleasantly surprised with it being fairly seamless. There's a relevant file `src/zig-gdb.py` in the repo, but GDB works fine on Zig code without it.

For example:

```bash
./zig test ../lib/std/zig/parser_test.zig -femit-bin=parser_test
gdb parser-test
(gdb) b parser_test.zig:3146
(gdb) b render.zig:1009
(gdb) disable 2
(gdb) r zig
```

I'm not sure if there's a way to add breakpoints on Zig tests or struct functions other than with line number. I was also unable to call struct functions from within GDB, but this isn't a big deal to me.

Another difference with C is that arrays are stored as a struct so that their length is always available, and the regular array can be accessed with the '`ptr`' field:
```
(gdb) p token_tags
$1 = {ptr = 0x2e0124 <fixed_buffer_mem+292>, len = 22}
```

I also learned of the GDB '`printf`' command!


## Community

This time I've been hanging out on IRC (<https://webchat.freenode.net/#zig>) rather than Discord. This has its pros and cons - there's less functionality (e.g. formatting, reactions) but it's more lightweight and I don't have to worry about which room to use!

Everyone has continued to be very welcoming and helpful, especially Andrew who takes the time to welcome and encourage anyone who comes along (I first noticed this on his streams, which has encouraged me to get involved).

The community has quite a different feel to the Python community, which is the open source community I've had the most involvement in. This is no surprise given the difference in size/popularity/age, but I find it quite refreshing.

I particularly enjoyed:
```
Me: Hey andrewrk I've been working on a fix for https://github.com/ziglang/zig/issues/8088 and have just managed to get it working [...]
Andrew: nice work LewisGaul - give me a few minutes to solve this other issue and then I'll send a code review your way :)
```

Two minutes later I had another contributor (core dev?) taking a look anyway!

This is in stark contrast to the experience I've had with Python when running [EnHackathon](https://enhackathon.github.io/), and as can be seen by a comparison of open PRs: 1400 for CPython, 35 for Zig! This is less due to lack of development on Zig, and more due to the sheer volume of stale PRs in the CPython project (which is an acknowledged issue).


## Closing Remarks

As with getting involved on any sizable project, it took a bit of head-scratching to find a solution to the problem at hand, at the same time grappling with new tools and workflows. However, I believe in the value of trying new things and getting a wide range of experience, and I personally find it quite rewarding.

My PR hasn't been reviewed or merged yet, but I'm confident it will be soon. I'll probably do a bit more user-land stuff with Zig next, but I will keep my eyes open for other core contributions that look appealing. I'm still feeling pretty positive about the language and I'm excited about its future!


## Bonus Trivia

A quote from Andrew Kelley I liked, in response to "there's such a thing as 'while else'?", illustrating consistency in the language:

"while and if are the same thing except a while's body loops"
