---
title: "The Python Tooling Revolution: Ruff and Uv"
layout: post
categories: [coding]
tags: [python, packaging]
---

Python has been around for over 3 decades and has had continual tooling developments, and since the last couple of years it feels like things are starting to come together quite nicely.
This is in big part thanks to [Astral](http://astral.sh/) providing tools `ruff` anf `uv`, but also thanks to hard work of people pushing through packaging PEPs.

New programming languages tend to provide their own tooling (formatting, linting, build/packaging), which gives a smooth homogeneous experience when working with the language.
For example Rust provides Cargo, Zig bundles everything into the `zig` command, etc.
On the other hand we have older languages like C, C++, and Python whose tooling is playing catch-up with all the baggage of existing use-cases that must continue to be supported.


## Python's Tooling Model

Python does not directly provide tooling as a core part of the language.
However there is a "Python Packaging Authority" (PyPA, <https://www.pypa.io/>) with an associated PEP process for packaging standards (<https://peps.python.org/topic/packaging/>).
This standards-driven approach allows for interoperability with other third-party tooling.

The well-known tool `pip` is managed under the "pypa" GitHub org (<https://github.com/pypa/pip/>) alongside various other tools such as `virtualenv`, `build`, `twine`, `flit`, `hatch` and `pipenv` (see a full list at <https://packaging.python.org/key_projects/>).
This illustrates that PyPA is not intended for providing a single tool for Python packaging, since this list includes overlap in functionality.
There are other popular packaging projects such as `poetry`, `pdm`, `tox`, `nox`, and `uv` from Astral (discussed below).

Tools for formatting and linting are entirely separate, with popular options being `black`, `isort`, `import-linter`, `flake8`, `pylint`, and `ruff` from Astral (discussed below).

Additionally there are type checkers, with `mypy` being the most well-known tool, provided under the "python" GitHub org (<https://github.com/python/mypy/>) alongside CPython itself.
This doesn't really make `mypy` *the* type checker - Python's typing is fully backed by a specification, meaning there are other compliant type checking implementations.
One of the most widely used alternatives is `pyright`, used via the `pylance` VSCode extension.
For some reason each of Microsoft, Google and Meta have their own type checkers, `pyright`, `pytype` and `pyre` respectively.

Unfortunately this proliferation of tooling, especially with the evolution of Python packaging and interactions with different OS systems, this has led to a popular XKCD: <https://xkcd.com/1987/>.
There is certainly an argument for wanting a single tool like `cargo`, but also advantages of allowing room for independent projects to innovate and for users to pick their preferred workflow (see [this discussion](https://discuss.python.org/t/wanting-a-singular-packaging-tool-vision/21141/)).
I think the most important thing is providing an obvious set of steps for beginners or people new to working with a project.


## Recent Packaging PEPs

Below is a list of some recent packaging PEPs which have been gradually transforming Python's packaging story and paving the way for tooling interoperablity.

* **[PEP 518](https://peps.python.org/pep-0518/) (May 2016) - Specifying Minimum Build System Requirements for Python Projects**
  * Introducing `pyproject.toml` for specifying how a project should be built (defaulting to `setuptools`).
* **[PEP 621](https://peps.python.org/pep-0621/) (Nov 2020) - Storing project metadata in pyproject.toml**
  * Expanding use of `pyproject.toml`, endorsing tool configuration being included.
* **[PEP 723](https://peps.python.org/pep-0723/) (Jan 2024) - Inline script metadata**
  * Allow a script to specify its metadata inline, such that tools can automatically install dependencies.
  * This has been praised in a [Discourse thread](https://discuss.python.org/t/in-praise-of-pep-723/84039/).
* **[PEP 735](https://peps.python.org/pep-0735/) (Oct 2024) - Dependency Groups in pyproject.toml**
  * Provides a mechanism for specifying groups of dependencies for project development without overloading project "extras".
* **[PEP 751](https://peps.python.org/pep-0751/) (pending) - A file format to record Python dependencies for installation reproducibility**
  * Introducing `pylock.toml` as a proper standardised lockfile, replacing pip-oriented `requirements.txt`.


## Choosing Project Tools

There are a few considerations when choosing the tools you want to use for a project:
* Are there other maintainers?
* Are there other users who will interact with the project in a development environment?
* What's the purpose of the project? Throwaway scripting/long-lived, early development/slow-changing, application/library...
* What environments are being targeted? Linux/Windows/Mac, which Python versions are being supported, ...

Here are some example scenarios I've worked with:
* Long-lived open source "application" project, where I'm the only maintainer ([minegauler](https://github.com/LewisGaul/minegauler/tree/a600c45c2204ad8041d374e64f54bf8430565793/))
  * Use `pyproject.toml` to specify project metadata and tooling configuration (as standard).
  * Full adoption of `uv`, including a `uv.lock` file and a `dev` dependency group.
  * Adoption of `ruff` as the project linter.
  * Continued use of `black` and `isort` (could be switched to `ruff`, but prefer uniform IDE configuration across projects, and the formatting offered by `ruff` is not completely compatible with `black`).
* Long-lived open source "library" project, where I'm a secondary maintainer ([python-on-whales](https://github.com/gabrieldemarmiesse/python-on-whales/tree/9621e92614cc60f17203f0628440d570d060cded/))
  * Use `pyproject.toml` to specify project metadata and tooling configuration (as standard).
  * Has migrated to use `ruff` and `uv`, but this wasn't a decision I could have made unilaterally!
* New long-term work project shared with other maintainers
  * Use `pyproject.toml` to specify project metadata and tooling configuration (as standard).
  * Use `dev` dependency group but export to `requirements.txt` rather than `uv.lock` to support other team members' non-uv workflows.
  * Use `ruff`, `black`, `import-linter` and `mypy`, where `ruff` has been configured to run the `isort` rules but `black` is used for common IDE setup.
* Throw-away scripting/proof-of-concept
  * Just use `uv` to manually set up a virtual environment, use `black` and maybe `ruff` with default settings.


## Ruff

[Ruff](https://docs.astral.sh/ruff/) was the first Python tool produced by Astral, which is a linter and formatter with a big focus on performance (see the link).

I was previously an enthusiastic `black` user and semi-reluctant `pylint` user.
I hesitated before picking up `ruff`, not wanting to just use the *latest hip thing* - I prefer to favour consistency and stability across projects.
However, when trying `ruff check` the benefits were immediately obvious: performance is incredible, provides a superset of the `pylint` rules, reporting of errors is very clear, configuration is straightforward, documentation is excellent, there is clean separation of rules in preview mode, and above all else the `--fix` flag is a huge win to automatically fix certain rule violations.

On the other hand I have not switched from `black` to `ruff format`.
This is partly because I have less complaints with `black` than `pylint`, so less need to switch.
However, the bigger reason is wanting consistency between projects, where it is expected for developers to have the IDE set up to run `black`, and the fact that there are some differences in the formatting between `black` and `ruff` is problematic in this case.

The `ruff` formatter has known deviations listed at <https://docs.astral.sh/ruff/formatter/black/>.
Many of these do look sensible/better.
However, my main complaint isn't actually mentioned there but at <https://docs.astral.sh/ruff/formatter/#format-suppression>: "`# fmt: on` and `# fmt: off` comments are enforced at the statement level".
This means that in the example below (which is by far my most common use of the `fmt: off` directive) `ruff` ignores the directive:
```python
subprocess.run(
    [
        # fmt: off
        "pytest", *paths,
        "-vvv",
        "--log-cli-level", "debug",
        "--report-dir", REPORT_DIR,
        # fmt: on
    ]
)
```

## Uv

After having such a good experience with `ruff`, I was a bit more keen to try out `uv`.
Being such a heavy user of Python I already had workflows that were fairly effective for me, mostly using `python3 -m venv` for creating virtual environments and pip with requirements files.
Without knowing much about `uv` the initial selling point was its purported speed.

### Initial Use - Installing Packages

Therefore, my initial use of `uv` was just to replace `pip` commands with `uv pip` commands - I think this drop-in interface is excellent for giving new users a way in without having to learn a new interface.
I don't think I was prepared for just how good the experience was.

Here's a message I sent immediately after trying it:
> uv is amazing, so fast...
>
> on WSL2:
> * `python3 -m venv .venv && .venv/bin/pip install -U pip wheel && .venv/bin/pip install -r requirements-dev.txt: 17s`
> * `python3 -m venv .venv && .venv/bin/pip install uv && .venv/bin/uv pip install -r requirements-dev.txt: 9s`
> * `uv venv && uv pip install -r requirements-dev.txt: 1s`

This was the start of me using `uv` for virtual environment creation and package installation by default!
In cases where I wanted to continue supporting `pip` workflows I simply used:
* To install dependencies:
  * `uv pip install [--all-extras] [--all-groups]`
  * `uv sync [--no-dev] [--all-extras] [--all-groups]`
* To create `requirements.txt` from a virtual environment:
  * `uv pip freeze > requirements.txt`
* Or all in one with format matching that from `pip-compile`:
  * `uv pip compile [--all-extras] [--all-groups] pyproject.toml -o requirements.txt`

I would then commit the `requirements.txt` and not commit the `uv.lock` file (since they would then need to be kept in sync).
There is also the option of using `--frozen` or `UV_FROZEN=1` to skip creation of the `uv.lock` file.

Note that `--all-groups` is not yet a released flag under `uv pip` commands, although [the PR](https://github.com/astral-sh/uv/pull/10861/) was merged 1 hour ago!
Also note that while `uv pip install` and `uv pip compile` match the behaviour of `pip install` and `pip-compile`, installing only the project's direct dependencies by default, `uv sync` defaults to installing the `dev` dependency group.

The `uv pip` interface is well documented at <https://docs.astral.sh/uv/pip/>.

### Uv Project Workflows

At some point, when working on a project where I opted to go all-in with `uv` (`uv.lock` instead of `requirements.txt`), I decided to try using the `uv add` command in place of `uv pip install` for adding a dependency to the project.
This command installs the dependency into the virtual environment, but it also updates the `pyproject.toml` dependencies!
Looking at `uv add --help` I then discovered `uv add --dev` for adding development dependencies (in the `dev` dependency group), which is installed by default by `uv sync` as mentioned above.

This is a fantastic workflow, defaulting to consistent use of modern Python packaging features.
For more details see <https://docs.astral.sh/uv/concepts/projects/dependencies/>.

An example `pyproject.toml` when using this `uv` workflow is shown below.
```toml
[project]
name = "myproject"
version = 0.1.0
dependencies = ["pyyaml"]

[project.optional-dependencies]
aws = ["boto3"]

[build-system]
requires = ["setuptools>=72.0.0"]
build-backend = "setuptools.build_meta"

[dependency-groups]
dev = [
  "pytest >=8.1.1,<9",
]
```

### Downloading Python Versions

I also heard from somewhere (probably Charlie Marsh on Twitter) that `uv` supports downloading requested Python versions via the `python-build-standalone` project (<https://github.com/astral-sh/python-build-standalone/>).
This provides another incredible piece in making running things under Python convenient in many different scenarios.
See <https://docs.astral.sh/uv/guides/install-python/> for more details.

For example, I can start a minimal rootless Alpine container and install Python:
```
(lewis)$ podman run --rm -it alpine
/ # apk add curl
fetch https://dl-cdn.alpinelinux.org/alpine/v3.20/main/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.20/community/x86_64/APKINDEX.tar.gz
(1/10) Installing ca-certificates (20241121-r1)
(2/10) Installing brotli-libs (1.1.0-r2)
(3/10) Installing c-ares (1.33.1-r0)
(4/10) Installing libunistring (1.2-r0)
(5/10) Installing libidn2 (2.3.7-r0)
(6/10) Installing nghttp2-libs (1.62.1-r0)
(7/10) Installing libpsl (0.21.5-r1)
(8/10) Installing zstd-libs (1.5.6-r0)
(9/10) Installing libcurl (8.12.1-r0)
(10/10) Installing curl (8.12.1-r0)
Executing busybox-1.36.1-r29.trigger
Executing ca-certificates-20241121-r1.trigger
OK: 13 MiB in 24 packages
/ # curl -LsSf https://astral.sh/uv/install.sh | sh
downloading uv 0.6.6 x86_64-unknown-linux-musl-static
no checksums to verify
installing to /root/.local/bin
  uv
  uvx
everything's installed!

To add $HOME/.local/bin to your PATH, either restart your shell or run:

    source $HOME/.local/bin/env (sh, bash, zsh)
    source $HOME/.local/bin/env.fish (fish)
/ # ln -s ~/.local/bin/uv /usr/bin/
/ # uv run -p 3.13 python3
Python 3.13.2 (main, Mar 11 2025, 17:21:04) [Clang 14.0.3 ] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>>
```

That magic `uv run -p 3.13` command is installing a standalone Python compatible with musl libc under the covers, as shown explicitly here:
```
/ # uv python install 3.12
Installed Python 3.12.9 in 2.45s
 + cpython-3.12.9-linux-x86_64-musl
```

This whole thing is taking under 10 seconds!
```
(lewis)$ time podman run --rm alpine sh -c '( apk add curl && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/bin/ sh ) >/dev/null && uv run -p 3.13 python3 -c "import sys; print(sys.version)"'
downloading uv 0.6.6 x86_64-unknown-linux-musl-static
Downloading cpython-3.13.2-linux-x86_64-musl (17.8MiB)
 Downloaded cpython-3.13.2-linux-x86_64-musl
3.13.2 (main, Mar 11 2025, 17:21:04) [Clang 14.0.3 ]

real    0m7.941s
user    0m0.111s
sys     0m0.000s
```

### Run Tools Without Virtual Environments

To add one *final* layer on top (although I recommend also looking at <https://docs.astral.sh/uv/guides/scripts/#declaring-script-dependencies>), `uv` supports installing packages and running a command in a single command.
Of course, this can be combined with the ability to install Python itself as shown above.

For example, to install and run `isort` you can simply use `uv tool run isort`.
Or, to run the latest version of `minegauler` from the `dev` branch you can simply run: \
`uv tool run --from git+https://github.com/LewisGaul/minegauler.git@dev minegauler`

Note that `uv tool run` is equivalent to `uvx`, which is shorter if you have it downloaded!

See <https://docs.astral.sh/uv/concepts/tools/> for more details on `uv tool` commands.

### Updating Uv

If `uv` was installed using the script provided on the website, then to update you can simply run `uv self update`.
This seems to just bring in more and more amazing features and improvements!


## Sample Project Configuration

Here's a sample `ruff` configuration snippet from `pyproject.toml` that I like to use, including enabling `isort` rules.
```toml
[tool.ruff.lint]
exclude = [
    "src/myproject/_version.py",
]
select = [
    # pydocstyle
    "D",
    # Pyflakes
    "F",
    # pycodestyle
    "E",
    # isort
    "I",
    # pep8-naming
    "N",
    # pyupgrade
    "UP",
    # flake8-2020
    "YTT",
    # flake8-async
    "ASYNC",
    # flake8-bandit
    "S506",  # unsafe-yaml-load
    # flake8-bugbear
    "B",
    # flake8-executable
    "EXE",
    # flake8-pie
    "PIE",
    # flake8-pyi
    "PYI",
    # flake8-simplify
    "SIM",
    # pylint
    "PLE",      # errors
    "PLW",      # warnings
    "PLR1711",  # useless-return
    # Ruff-specific rules
    "RUF",
]
ignore = [
    # pydocstyle
    "D105",  # undocumented-magic-method
    "D107",  # undocumented-public-init
    "D203",  # one-blank-line-before-class
    "D205",  # blank-line-after-summary
    "D212",  # multi-line-summary-first-line
    "D401",  # non-imperative-mood
    # Pyflakes
    "F403",  # undefined-local-with-import-star
    "F841",  # unused-variable
    # pycodestyle
    "E402",  # module-import-not-at-top-of-file
    "E501",  # line-too-long
    # pep8-naming
    "N802",  # invalid-function-name
    # pylint warnings
    "PLW3201",  # bad-dunder-method-name
    # flake8-pyi
    "PYI041",  # redundant-numeric-union
    # pyupgrade
    "UP015",  # redundant-open-modes
    "UP032",  # f-string
    # flake8-bugbear
    "B011",  # assert-false
    # Ruff-specific rules
    "RUF028",  # invalid-formatter-suppression-comment
    # flake8-simplify
    "SIM102",  # collapsible-if
    "SIM108",  # if-else-block-instead-of-if-exp
    "SIM117",  # multiple-with-statements
]
task-tags = ["TODO", "FIXME", "XXX", "@@@"]

[tool.ruff.lint.isort]
lines-after-imports = 2
section-order = [
    "future",
    "standard-library",
    "third-party",
    "internal",
    "first-party",
    "local-folder",
]
sections.internal = ["myproject_internal"]
```

The `_version.py` file is excluded because it is generated by `hatch-vcs` (a project related to `hatch`/`hatchling`, an alternative to `setuptools` in this case), which gets the version from the project's git tags (`setuptools-scm` is another project that does this).

For completeness, the section of config for the project build looks like:
```toml
[project]
name = "myproject"
dynamic = ["version"]

[build-system]
requires = ["hatchling", "hatch-vcs"]
build-backend = "hatchling.build"

[tool.hatch.version]
source = "vcs"

[tool.hatch.build.hooks.vcs]
version-file = "src/myproject/_version.py"
```

In `src/myproject/__init__.py` I then have:
```python
try:
    from ._version import __version__
except ImportError:
    __version__ = "unknown"
```


## Conclusion

Astral has introduced two amazing tools, which are reliable, blazingly fast, have incredible documentation, are well maintained, and deserve all the praise they're getting.
I couldn't agree with the company's [stated beliefs](https://astral.sh/about) more strongly:
> We believe that a great tool can have an outsized impact.
> 
> – That a great tool can multiply the effectiveness of individual developers, teams, and entire organizations.
> 
> We build in the open. Our tools are open source and permissively licensed.
> 
> We strive to advance existing standards and integrate with the broader ecosystem.
> 
> We value openness. We value action. We value craft.

Ruff provides an incredible linting experience, especially with the auto-fixing mode.
Uv is absolutely transformative, combining with PEPs 723 (*Inline script metadata*) and 725 (*Dependency Groups in pyproject.toml*) to provide workflows never seen before in the Python ecosystem, surely obsoleting a huge number of custom-rolled solutions to the same problems.

There are two upcoming things I'm keeping a close eye on.
The first is the [announcement from Charlie Marsh](https://x.com/charliermarsh/status/1884651482009477368) in January that Astral is working on a type checker, tracked by <https://github.com/astral-sh/ruff/issues/3893>.

The second is [PEP 751](https://peps.python.org/pep-0751/) (*A file format to record Python dependencies for installation reproducibility*), which should hopefully remove the awkwardness around choosing between `requirements.txt` and `uv.lock` for locked dependencies, where we can be hugely confident that `uv` will support exporting to this new `pylock.toml` format, probably before any other tool out there!
