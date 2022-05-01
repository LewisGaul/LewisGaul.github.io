---
title: Zig NestedText Library
layout: post
categories: [coding]
tags: [zig, open-source, parser, nestedtext]
---

## Introduction

This post is going to be a little different to others I've written in that it's consciously aimed at those who may be interested in using NestedText, or users of Zig who are looking for a library for parsing a human-friendly data format.

You can find my project at <https://github.com/LewisGaul/zig-nestedtext>.

I've been playing around with Zig for a few months at this point, and this is my third blog post on the subject. You can find my previous posts at [Trying out Zig - Zigominoes](../../../01/10/trying-zig) and [First Contribution To Zig](../../../03/02/first-zig-contribution). Since writing the last post I have had a total of [6 PRs merged](https://github.com/ziglang/zig/pulls?q=is%3Apr+author%3ALewisGaul+is%3Amerged) into the Zig repo, all thanks to encouragement from the core team!


## NestedText

Homepage: <https://nestedtext.org/>

NestedText is a simple, human-friendly data format I discovered recently, which is one of various data formats based on simplifying YAML. NestedText is not a strict subset of YAML, instead aiming to stand on its own merits, with a complete [specification](https://nestedtext.org/en/latest/file_format.html) and [testsuite](https://github.com/KenKundert/nestedtext_tests).

Quoting from the homepage:

> it is similar to JSON, YAML and TOML, but without the complexity and risk of YAML and without the syntactic clutter of JSON and TOML

> easily understood and used by both programmers and non-programmers

Snippet from the example on the homepage:

```nestedtext
# Contact information for our officers

president:
    name: Katheryn McDaniel
    address:
        > 138 Almond Street
        > Topeka, Kansas 20697
    phone:
        cell: 1-210-555-5297
        home: 1-210-555-8470
            # Katheryn prefers that we always call her on her cell phone.
    email: KateMcD@aol.com
    additional roles:
        - board member
```


### Crazy YAML

I like YAML - it succeeds in being an easy to read and write data format. Below is an example.

```yaml
- first-name: Barbara
  surname: Lighthouse
  age: 10
  country: GB
- first-name: Broccoli
  surname: Highkicks
  age: 12
  country: GB
- first-name: Mavis
  # No surname - can just omit the field.
  species: owl
  age: 1
  country: FR
```

Here we have a list containing three objects, where object keys are strings and values can be interpreted as different types. By default values are strings (and can also be represented using quotes), but numbers are interpreted as such, and `null` can be used to represent a missing value (as in JSON).

However, there are some really wacky gotchas in YAML. Say we wanted to add another object to the list:

```yaml
- first-name: Ronnie
  surname: Omelettes
  age: 30:6  # 30 years and 6 months
  country: NO  # Country code for Norway
```

You would think that '`30:6`' would be interpreted as a string since it's no longer a number (or perhaps as a nested object?), but this is actually interpreted as the number `1806`! This is being treated as a timestamp (e.g. 30 minutes and 6 seconds) - to enforce it to be treated as a string it would need to be enclosed by quotes.

You would think that '`NO`' would be interpreted as a string, just like '`GB`' and '`FR`' are, but this is actually interpreted as `false` because it's read as the word 'no'! Again, this needs to be quoted.

There are also **9 ways** to represent multi-line strings in YAML, as explained in [this Stack Overflow answer](https://stackoverflow.com/a/21699210/5181656).


### Other Alternatives

JSON is a very widely used data format, but I would argue its strength is in providing a simple way for computers to transfer data (in a format that is still comprehensible by humans!). There are cases where the priority should be on ease of use for an end-user, who may not necessarily be tech-savvy (depending on target audience of your project). JSON's use of curly braces and quotes for all strings makes it less human-friendly (especially when not spread out over multiple lines), and it's also impossible to include comments. Translating the above YAML to JSON:

```json
[{"first-name": "Barbara", "surname": "Lighthouse", "age": 10, "country": "GB"}, {"first-name": "Broccoli", "surname": "Highkicks", "age": 12, "country": "GB"}, {"first-name": "Mavis", "species": "owl", "age": 1, "country": "FR"}]
```

TOML is a relatively new data format based on the INI configuration syntax. My impression of TOML is generally positive - it has been adopted for [`pyproject.toml`](https://www.python.org/dev/peps/pep-0518/#file-format) and [`Cargo.toml`](https://doc.rust-lang.org/cargo/reference/manifest.html) files. However, it's not great for representing arbitrary data. It actually seems to be impossible to represent a list at root level. If I try to represent the above YAML by sticking it in an object with an empty string key it looks like:

```toml
[[""]]
first-name = "Barbara"
surname = "Lighthouse"
age = 10
country = "GB"

[[""]]
first-name = "Broccoli"
surname = "Highkicks"
age = 12
country = "GB"

[[""]]
first-name = "Mavis"
# No surname - can just omit the field.
species = "owl"
age = 1
country = "FR"
```

There are other YAML simplifications out there, for example [`strictyaml`](https://github.com/crdoconnor/strictyaml), which is fairly similar to NestedText but with over 800 stars on GitHub. One of the major problems with this example is that [it has no formal spec](https://github.com/crdoconnor/strictyaml/issues/98).


### Status of NestedText

NestedText was first released very recently, in October 2020, and already has nearly 200 stars on GitHub. It has started off as a Python implementation, and the spec/testsuite have been slightly prised apart from this one implementation since the first release. My Zig implementation is the only other implementation that I'm aware of (although I may also continue with my [simplified Python implementation](https://github.com/LewisGaul/nestedtext) at some point).

Below is the above example converted to NestedText (this example is actually valid YAML). Note the key difference: all values are interpreted as strings ('text'), and it is up to the application consuming the data to interpret fields as specific types.

```yaml
-
  first-name: Barbara
  surname: Lighthouse
  age: 10
  country: GB
-
  first-name: Broccoli
  surname: Highkicks
  age: 12
  country: GB
-
  first-name: Mavis
  # No surname - can just omit the field.
  species: owl
  age: 1
  country: FR
```

The NestedText spec is still not fully stabilised. This is something I'm pleased about - I've been able to give feedback to the creators and get traction on making improvements:

 - [Discussion on removing quoting in object keys](https://github.com/KenKundert/nestedtext/issues/21)
 - [Discussion on syntax for mult-line object keys](https://github.com/KenKundert/nestedtext/issues/23)
 - [Discussion on representing empty containers](https://github.com/KenKundert/nestedtext/issues/24)
 - [Questions/suggestions on details of the spec](https://github.com/KenKundert/nestedtext_tests/issues/3)

If you have any thoughts on any of the above, please do join in on the discussion and help guide the development of the language spec!


## Zig Implementation

I have written a Zig implementation of a NestedText parser: [zig-nestedtext](https://github.com/LewisGaul/zig-nestedtext). This can be used in a few different ways:
 - Use my project as a package dependency
 - Build my project and link the generated `libnestedtext.a` (I'm not sure how this is done in Zig yet!)
 - Use the CLI tool included in the project for converting between NestedText and JSON (it's pretty fast!)

My implementation is based on the implementation of `std.json` - the JSON module in the Zig standard library. Working on this project led me to notice that the order of JSON objects is not maintained by `std.json`, and my suggestion to change this behaviour was accepted in [PR-8422](https://github.com/ziglang/zig/pull/8422).

Examples of using the Zig API can be found in the [tests in `nestedtext.zig`](https://github.com/LewisGaul/zig-nestedtext/blob/f04419fc9335f77212c6cd4f3a611ed722da571f/src/nestedtext.zig#L571) and [the `cli.zig` implementation](https://github.com/LewisGaul/zig-nestedtext/blob/main/src/cli.zig). A snippet is given below.

```zig
const std = @import("std");
const testing = std.testing;
const Parser = @import("nestedtext").Parser;

test "convert to JSON: list of strings" {
    var p = Parser.init(testing.allocator, .{});

    const s =
        \\- single line
        \\-
        \\  > multi
        \\  > line
    ;

    var tree = try p.parse(s);
    defer tree.deinit();

    var json_tree = try tree.root.toJson(testing.allocator);
    defer json_tree.deinit();

    var buffer: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    try json_tree.root.jsonStringify(.{}, fbs.outStream());
    const expected_json =
        \\["single line","multi\nline"]
    ;
    testing.expectEqualStrings(expected_json, fbs.getWritten());
}
```


## What's Next?

The Zig JSON module has the ability to parse JSON directly into Zig structs - this is something I might look into adding for my NestedText parser. It may be especially useful for NestedText given this could handle parsing the string values to typed values, which would otherwise need to be done manually.

There are also some ongoing discussions about the NestedText spec (linked above) that I will continue to engage in, with the hope we can settle on something that won't need to change much more as people increasingly start to make use of it.

If anyone has any questions or suggestions for improvements feel free to get in touch, either via an [issue](https://github.com/LewisGaul/zig-nestedtext/issues/new) or [by email](mailto:lewis.gaul@gmail.com).

I'm intending to put most of my focus over the coming weeks into increasing my ability to contribute to core Zig (perhaps on the self-hosted compiler work if I can find a way in!). In the long term I may decide I have more interest in implementing Zig libraries like this one - I'm keen to bring some of the incredible usability of Python and its ecosystem of packages to Zig. Let's see how it goes!
