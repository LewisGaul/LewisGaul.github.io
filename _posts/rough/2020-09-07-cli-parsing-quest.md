---
title: CLI Parsing Quest
layout: post
categories: [rough, coding]
tags: [python, cli, library]
---

## Introduction

I made a start to a new project. It could end up being a huge undertaking to take it as far as I'd like to, but the hope is that it could actually be useful to people!

The aim is to simplify and enhance the solution to a problem that is regularly tackled by software engineers - defining CLIs (command-line interfaces). This could include anything from a regular command-line application to bots or interactive shells, although the focus (at least initially) is on the former.

I have actually spent some time in this area a couple of times before - a bit on the concept of an interactive CLI back in 2018, and the [minegauler bot](https://github.com/LewisGaul/minegauler/blob/v4.0.5/server/bot/msgparse.py) in 2020. I've also been involved in implementing a CLI application at work (using Python's `argparse`).

I feel happy with the approach to generically tackle the problem this time. However, when opting for a generic approach there can end up being a huge number of considerations and choices to make! One reason for writing this post is to help give me some focus on how to approach the project - the preference should be for an iterative approach, rather than having nothing to show until after months of development.


## Project Fundamentals

Core principles of the project include:
 - **The most important consideration is the user experience**;
 - Modular approach, with each unit providing a distinct piece of overall functionality that can stand alone if desired;
 - Clean and clear internal APIs to enable low-cost rewrites of units of code;
 - Seek to minimise complexity (see modularity point above);
 - Minimise dependencies;
 - General project good-practice (examples, tests, CI, versioning, documentation, ...).

Summary of general project goals:
 - Decouple the definition of a CLI from how it is presented;
 - Enable declaring a CLI in a static manner (initially in YAML format);
 - Provide various front-ends to serve the CLI (initial focus to be based on Python's `argparse`);
 - Support most/all of standard CLI structures (may need to be opinionated in some cases to standardise across multiple front-ends, but should have full functionality);
 - Provide an API for users to obtain the result of CLI parsing (initial focus is on a Python API).

Potential long-term goals:
 - The CLI declaration should be modular to minimise the need for repetition;
 - May wish to support other static declaration formats (perhaps even eventually define a domain-specific language);
 - Provide validation and useful error messages for CLI declaration;
 - Should be non-specific to Python (provide APIs to other languages, e.g. bash).


## Early Steps

I created a [GitHub repository](https://github.com/LewisGaul/declarative-cli) and made a start on implementation - the master branch should be stable and the README gives some example usage in case anyone wants to try it out.

The effort has stalled for now since I noticed a similar approach has already been used by the Rust library 'Clap' (see [here](https://github.com/clap-rs/clap#using-yaml)).
