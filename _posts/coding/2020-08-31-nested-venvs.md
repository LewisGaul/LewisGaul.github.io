---
title: Issues With Nested Python Virtual Environments
layout: post
categories: [coding]
tags: [python, virtualenv, venv, tips]
---

## Introduction

This blog post is a by-product of my attempt to script virtual environment creation for one of my Python projects. My setup happened to fall into a case where `virtualenv` (3rd party) and `venv` (stdlib) do not play nicely together! In actual fact, I think I hit the same issue in the past without knowing what was going wrong. I did some digging and decided to write up my findings to help anyone hitting the same/similar issues.

To start with, for anyone not familiar with the different virtual environment options, [this Stack Overflow answer](https://stackoverflow.com/a/41573588/5181656) provides a great summary. The focus in this post is on `virtualenv` and `venv`, which I would call the two most popular options.


## The Main Issue

After some searching on the internet, I found that an old version of the virtualenv docs talks about the issue I hit, which you can find at <https://virtualenv.pypa.io/en/16.7.9/reference.html#compatibility-with-the-stdlib-venv-module>.

I'll summarise here:
 - virtualenv and venv use quite different techniques for creating virtual environments;
 - problems can arise when 'nesting' virtual environments (creating a virtual environment using a python executable from another virtual environment);
 - there has not been continuous support for this 'nesting' between virtualenv and venv environments.


### Reproducing the issue

I'm using Python 3.6.9 and virtualenv 15.1.0 to reproduce this issue below, but I don't believe it to be specific to these exact versions. Note that the issue appears to be fixed by virtualenv in version 20.0.0 (branded "a complete rewrite of the package", released in early 2020, where the version jumped from 16.7.10).

Create a first layer of virtual environments:
 - `python3 -m venv venv0`
 - `virtualenv -p python3 virt0`

Create a second layer using python executables from the virtual environments created above:
 - `./venv0/bin/python3 -m venv venv0-venv1`
 - `./virt0/bin/python3 -m venv virt0-venv1`
 - `virtualenv -p venv0/bin/python3 venv0-virt1`
 - `virtualenv -p virt0/bin/python3 virt0-virt1`

The broken case is when Python's stdlib `venv` is used to create a virtual environment using a python executable from a virtual environment created by `virtualenv`, as you can see below in `virt0-venv1/`.

```
$ ls | xargs -I % bash -c "echo % && ls %/bin/ && echo"
venv0/
activate      activate.fish  easy_install-3.6  pip3    python
activate.csh  easy_install   pip               pip3.6  python3

venv0-venv1/
activate      activate.fish  easy_install-3.6  pip3    python
activate.csh  easy_install   pip               pip3.6  python3

venv0-virt1/
activate      activate.fish     easy_install      pip   pip3.6  python3    python-config
activate.csh  activate_this.py  easy_install-3.6  pip3  python  python3.6  wheel

virt0/
activate      activate.fish     easy_install      pip   pip3.6  python3    python-config
activate.csh  activate_this.py  easy_install-3.6  pip3  python  python3.6  wheel

virt0-venv1/
activate  activate.csh  activate.fish  python  python3

virt0-virt1/
activate      activate.fish     easy_install      pip   pip3.6  python3    python-config
activate.csh  activate_this.py  easy_install-3.6  pip3  python  python3.6  wheel
```

In this case, when using pip it will silently use the underlying virtualenv-based virtual environment!

```
$ source virt0-venv1/bin/activate
$ which python3
<cwd>/virt0-venv1/bin/python3
$ python3 -m pip --version
pip 20.2.2 from <cwd>/virt0/lib/python3.6/site-packages/pip (python 3.6)
```


### Discussion

This issue has been raised on Python's bug tracker against venv (see [here](https://bugs.python.org/issue30811)) and against virtualenv (see [here](https://github.com/pypa/virtualenv/issues/1095)). The consensus seemed to be that this was virtualenv's problem to fix - and it has been fixed in version 20. However, I'm sure there are still lots of users with an earlier version of virtualenv (version 20 was realeased only this year), and upgrading virtualenv alone is not enough because any existing virtual environments created with an old version of virtualenv will remain incompatible with venv.

The result of this is that blindly running `python3 -m venv my-venv` (e.g. in a script) may create a 'bad' virtual environment, as above, in the case where the `python3` executable lives in a virtualenv (pre version 20) environment. Now for the good news: there is a way to deal with this! 

Note the following:
 - Virtualenv (pre version 20) has its own `site` module, which is implemented differently to the `site` module in stdlib. This leads to the inner-venv having a wrong `sys.prefix` value.
 - In a venv environment, `sys.base_prefix` stores the path to the original python executable (otherwise the current executable).
 - In a virtualenv environment (prior to version 20), `sys.real_prefix` contains the path to the original python executable (otherwise not set), and `sys.base_prefix` always stores the current executable.
 - Since virtualenv version 20 `sys.base_prefix` is set correctly and `sys.real_prefix` is no longer set.

Therefore a general solution could be to check `sys.real_prefix`, and, if set, use the original python executable at this path to create a virtual environment with venv. Otherwise there should be no issues with 'nesting' virtual environments, but to be safe `sys.base_prefix` could be used to get the original python executable.

```python
import os.path, sys, subprocess

if hasattr(sys, "real_prefix"):
    prefix = sys.real_prefix
else:
    prefix = sys.base_prefix
exe = "python.exe" if sys.platform.startswith("win") else "bin/python3"
python_path = os.path.join(prefix, exe)
subprocess.run([python_path, "-m", "venv", "my-venv"])
```

As a final note, in the case `sys.real_prefix` is not set, to determine whether running in a virtual environment simply compare `sys.base_prefix` to `sys.prefix`.


## Another Similar Issue

Note that it seems there was a separate problem with similar symptoms, caused by a change to `venv` in Python 3.7: <https://bugs.python.org/issue35872>, <https://github.com/pypa/virtualenv/issues/1339>, but this seems to have been patched up quite quickly.
