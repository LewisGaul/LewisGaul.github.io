---
title: Pet Peeves in Software Development
layout: post
categories: [coding]
tags: [style, opinion]
---

All software engineers develop their own taste and style, and naturally people form differing opinions.
I decided to write down some of my personal pet peeves so that I have a link to point to when these things come up in discussion/review!

I like to avoid being too opinionated online, but hopefully most of my points in this post aren't actually very controversial!


## User Interfaces

When writing code that users are expected to interact with in some way the primary design consideration should be the usability of the interface.

Breaking this down, this statement actually applies to nearly *all* software - whether it's a command-line interface, a graphical/web user interface, or an internal API where the 'user' is just another unit of code.

One of the key factors in usability across software interfaces is **naming** (also one of the hardest problems in software!).
Another hugely important factor is consistency, and this will often override the naming point (you might think of this in terms of "practicality over purity").

### CLI Tools

There are some basics that CLI tools should support.
However, it's worth considering how/where the tool is expected to be invoked.

If there's a bash script that's only intended to be run from another bash script then that's more of a programmatic API than a CLI tool.
If there's a script intended to be run by internal project developers then it's less important to get right than a script that's being provided to end-users.

Points to consider (in a vague order of importance):
- `-h` and `--help` should output the tool's usage
  - When these args are passed the script should *never* go off and do something that has side effects, as the user may have just wanted some help!
- Give the correct exit code
  - If success then exit code 0, if there was an error then give a non-zero exit code.
  - Maybe consider using different codes for different types of error.
- Use the appropriate output stream
  - Output all warnings/errors to `stderr`, not `stdout`.
  - Any standard output intended for the user should go to `stdout`.
  - Log messages should probably go to `stderr` (and/or a file).
- All short options should have a corresponding long option
  - Short options are convenient for manual invocation, but when invoking from another script it's clearer to use a long option.
  - Also makes the help output easier to scan over.
- All long options should be hyphenated (*kebab-case*), not *snake_case*
  - This is just standard convention...
- (Unix) Scripts intended for end-users should not have an extension in the filename
  - Use a shebang line.
  - The language used should be an implementation detail - the user should not have to care.
- Scripts intended for end-users should be hyphenated (*kebab-case*), not *snake_case*
  - This matches the convention with long options.
  - Seems more standard in the Linux ecosystem.
- If your script wraps another script then take inspiration from its options
  - Avoid redefining a short option to behave differently to the wrapped tool.
- Avoid using common short options for non-standard purposes
  - `-h` should mean `--help`.
  - `-v` often means `--verbose`.
  - `-q` often means `--quiet`.
  - `-f` often means `--force`.
  - `-n` often means `--dry-run`.
  - `-l` often means `--list`.
  - `-a` often means `--all`.

### APIs

Design the APIs first, build the code around them. Making an API decision based on an implementation consideration should be avoided *unless* it's another case of practicality over purity (e.g. the implementation would be too much effort or too slow unless the API is simplified).

An API should be an abstraction that makes sense to a user of the API, and it's important to think about what context that user is expected to have (even if the 'user' is just another internal module of your own project).
Avoid confusing naming abbreviations on API boundaries.
Think about how users of the API might want to use it, and make this as seamless as possible, even if it makes the implementation more complicated.


## Code Cleanliness

Nobody wants ugly, messy code.
Certainly nobody wants to work with someone else's mess.
So how do we avoid the mess and keep things tidy?

### Formatting

The most important thing with code formatting (aside from basics such as correct indentation) is that it's consistent within the project.
Of course, the problem with this is that anyone contributing to the code for the first time must first learn the formatting conventions to maintain consistency.

The solution to this, which seems to be rapidly growing in popularity and becoming standard, is to use a code auto-formatter.
Many modern languages come with their own auto-formatters, including Rust, Go, Elm, Zig.
The Python ecosystem has also more-or-less standardised on the `black` auto-formatter.

Auto-formatters are not perfect - it's impossible for them to be because they don't understand the code.
However, in my opinion the benefit of having standardised formatting *across projects* hugely outweighs the small downsides (the formatting might not be exactly what you're used to, and might require turning off in certain rare cases).

Use an auto-formatter if you're using a language that has a standard popular choice!

#### Whitespace

There's an age-old tabs versus spaces argument that I'm not going to get into (obviously spaces), as well as a line endings argument (obviously `\n`).

More importantly (wink), I want to make the simple point that all code/text files should end in a newline.

Consider:
- "`cat file1 file2`" - if `file1` doesn't end in newline then the last line of `file1` is displayed on the same line as the first line of `file2`
- "`open(file1).readlines()`" - the last line would be the only one without a newline, which might be surprising
- searching for a pattern in a file - maybe you want lines ending in "foo", then you'd search for `"foo\n"`, but this wouldn't ever match the last line

### Static Analysis Tooling

Static analysis can be great for a few reasons:
- Catch bugs/suggest improvements
- Help ensure all project contributors follow the same conventions (e.g. check the auto-formatter has been run)
- Encourage clean design (e.g. motivated by making static typing easier)
- Can be run separately from the tests, e.g. as a faster first pass over code changes

Most of my experience of static checkers is with Python-based tools, primarily `pylint` (linting) and `mypy` (type checking).
I would expect the points here to stand with any language, but it's quite possible my perspective has been skewed in my limited exposure. Static checkers are effectively there to fill in for a limitation in the checks provided by the compiler, so I'd expect modern languages with a strict compiler to have less need for separate static analysis (e.g. Rust, Elm, Zig).

The big problem I see with static analysis tools is the number of false positives they highlight.
Sure, there are configuration files that allow you to disable checks you're not interested in, but some of the issues highlighted are due to bugs or lack of cleverness in the tool.
This problem seems to be exacerbated by the fact the tools are forever fighting to keep up with core language changes.

The standard solution, aside from editing the tool's config file, is to add a comment in the code to disable the tool on a specific line/block.
For example, you can disable all linting warnings on a line by appending "`# noqa`" - that's "no quality assurance", although I'm sure that was obvious (personally I read this as "no questions asked")...

This is a horrible solution.
Why are we adding clutter to code for the sake of running a tool that has bugs and/or doesn't have the required functionality to do its job properly?
The main argument I can see in favour of this is the "practicality over purity" one again - and don't get me wrong, I have used comments to disable static analysis warnings.
It just makes me very sad when I have to, and it should be avoided *as much as possible*.
Isn't it nice when the language's compiler already has all the checks you need...

This section is mostly a rant about static analysis tools, but the main take-away is: please don't clutter your code with comments disabling tools, I don't want to be distracted by that when trying to understand what the code is doing!

### Testing

#### Making The Code Testable

Never change the code for the sake of making testing easier *unless* it serves as an *improvement* to the code.

An example of an improvement driven by testing would be something like moving towards a 'clean architecture', where I/O is handled near the "edge" of the program.
Another example of a positive change would be simplifying the code's functionality, removing unnecessary features, or being more restrictive in other ways.
Simpler code is easier to reason about and easier to test, and that's a good thing.

An example of a bad change would be making an attribute/function part of a public API just so that it can be accessed by the tests.
This should be avoided *as much as possible*!
In Python it's not really a problem because nothing is truly private, but I'm aware languages like C and Java make things very awkward.
In general it's better to try and test at API boundaries anyway, but practically this isn't always the most effective way to write UT.

#### Usability Of Tests

If you have a set of tests, that's great, but it's not much use if they don't get run.

Ideally tests should be run automatically in a CI system before commit (or at least the majority, perhaps excluding some slower IT tests).
There should also be clear, simple instructions alongside the tests about how to run them manually!
The requirement for documenting tests is reduced if it's made clear that a popular framework should be used, such as `pytest`.

The majority of possible regressions should be caught in UT (unit tests), and that UT should be **fast**.
There is no excuse for slow UT - mock out any external effects that might make it slow (database access, timers, running commands, ...).
Make sure you have some IT (integration tests) as well, which does not have to have the same performance considerations.

### Object Oriented Programming

Classes represent types of objects, and methods are actions that the object can perform.
Objects are *nouns* and functions/methods are *verbs*.
Hopefully I'm stating the obvious!

I find that using classes to model objects can be helpful in modelling problems - that is, I like OOP.
However, in some cases there's just no need for thinking in these terms, and no need for implementing logic inside a class.
A plain and simple function is often sufficient (unless handcuffed by Java's over-the-top OOP).

When defining a class, the name should correspond to the type of object you're modelling.
It should be possible to imagine "one of those objects" (i.e. an instance), otherwise the abstraction you're building is unlikely to be very helpful.
If all you really want is to group some code together then using a class may be the wrong solution.

If a class forms part of an API, think about whether it makes sense for the user to work with the type of object you're defining.
Would it be simpler and easier for the user to simply invoke a function?
A function can still make use of a class under the covers - perhaps it would wrap the class by performing some setup before creating and returning the class instance.

### Code Readability

It's fine to use variables just to give a name to something, even if they're only used once.
Variables are cheap!
If introducing a single-use variable removes the need for a comment then that's a win.

Avoid putting too much on one line - I'd generally recommend restricting to one "piece of logic".
I also find it makes code clearer to avoid too much logic in a single *expression*.
That is, breaking over multiple lines can make things clearer, but the main point is to break up logically separate tasks over multiple blocks/expressions.

Similarly to the points above: break logic up into smaller functions, even if only used once.
If things need more grouping then split into classes/modules, or just use comment headings to break up a module.

If coming up with a clear name for a variable/function/class/module is difficult then it may be a sign that the purpose is unclear, and the structure should be reassessed.
Accepting that the names should be somewhat long may be the right answer.
Otherwise, perhaps consider putting the logic inside a namespace (module/class) such that the context is clearer - the names should then be able to focus on the specifics within that context without needing to set the scene.

## Closing Thoughts

I've probably forgotten to mention a few things that I'll soon be reminded of.
I'll probably just keep some notes of things that come up and consider writing a separate update post at some point in the future.

Feel free to tweet me with your thoughts and/or your own similar frustrations!
