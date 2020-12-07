---
title: Trying out Zig
layout: post
categories: [coding]
tags: [zig, language]
---


## Strings

<http://ciesie.com/post/zig_learning_01/>

> `[]const []const u8` is an const array of const arrays.

> Arrays and slices are two very similar concepts. Arrays have a length known during compile time, while slices length is changing during run time.

From Zig docs:

> Zig has no concept of strings. String literals are arrays of u8, and in general the string type is `[]u8` (slice of `u8`). Here we implicitly cast `[5]u8 to []const u8`:  
  `const hello: []const u8 = "hello";`

> A slice is a pointer and a length. The difference between an array and a slice is that the array's length is part of the type and known at compile-time, whereas the slice's length is known at runtime. Both can be accessed with the `len` field.


`return buf[0..pos];`

<https://ziglang.org/documentation/master/std/#std;fmt.format>
<https://ziglearn.org/chapter-2/#formatting>


## Functions

<https://ziglang.org/documentation/0.7.0/#Pass-by-value-Parameters>

> Structs, unions, and arrays can sometimes be more efficiently passed as a reference, since a copy could be arbitrarily expensive depending on the size. When these types are passed as parameters, Zig may choose to copy and pass by value, or pass by reference, whichever way Zig decides will be faster. This is made possible, in part, by the fact that parameters are immutable.

Seems to suggest there's no need to specify args as `arg: &MyType`, although I have seen this done with `&@This()` inside a struct in the stdlib?
