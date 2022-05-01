---
title: Language Design Dreams
layout: post
categories: [rough, coding]
tags: [programming, language, design]
---


Have you ever used a language and thought "*I wish that worked slightly differently*", or "*I wish it had \<feature X\>*"?

All languages have their quirks and warts, all languages are constrained by restrictive backward compatibility considerations, and all languages will have more appeal to certain people than others! There's no such thing as 'the right choice' when it comes to language design - there will always be trade-offs between performance, static checks, flexibility, complexity, ease-of-use, familiar style, novel ideas...

That being said, popular languages as a whole tend to move in certain common directions, taking inspiration from each other and finding themselves part of a feedback loop of demands from users shouting "Why can't we have that new feature too!".

To give some examples of high-level aims I perceive modern languages to have:
 * Descriptive error messages, possibly even suggesting fixes (thinking especially of Elm and Rust)
 * More static/compiler checks, catch errors earlier (Python's type annotations, Elm's "no runtime errors" philosophy, Rust's borrow checker...)
 * Built-in concurrency solution (async-await in many languages, Go's 'goroutines')

Note that my experience is mainly in Python, Elm, and C, with general interest but little experience in Rust, Go, Jai, and Zig, and diminishing knowledge of other popular languages like Java, Javascript, C++, Haskell... 


## Wishlist

Imagine you had a chance to influence the design of a new language. I expect the common (and totally reasonable!) approach would be to start picking your favourite bits of familiar languages. What would be your top 5 features?

If I were to think about my favourite features from existing languages, I'd have to start with Python, as the one I'm most familiar with. I think the biggest strength of Python is how easy it is to get going with. I believe this is achieved through a combination of the REPL, straightforward syntax, the ability to write code without needing functions or classes, the 'batteries included' standard library, and the dynamic ability to inspect any object. These aspects all make Python an enjoyable language to continue working with, especially for scripting purposes. Some other concepts I like in Python are context managers and exceptions, and the flexibility granted by the dynamic nature, which I find especially helps when writing tests.

If I could change anything about Python it would be the same kinds of things I expect anyone would wish for: better performance and more static checks. Unfortunately this would probably come at the cost of some of its dynamicness.

Then thinking about features of other languages I want to use more often, the main things that come to mind are algebraic data types (ADTs) and 'sound' type systems (thinking of Elm and Rust). I also think descriptive error messages and extensive checks performed by the compiler are hugely beneficial (again thinking of Elm and Rust!). Finally, I think it's important for packaging and deployment to be as simple and clean as possible (something Python struggles with).

So, let me try to get down a wishlist!
 * Algebraic data types (+ pattern matching)
 * Flow control for handling errors and cleanup (context managers/exceptions)
 * Strong packaging/dependency/deployment solution
 * Strong type system allowing compiler checks
 * High performance, or at least a convenient way to achieve high performance for critical parts of code
