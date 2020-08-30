---
title: Issues With Nested Python Virtual Environments
layout: post
categories: [rough, coding]
tags: [python, virtualenv, tips]
---


Using Python 3.6.9, Virtualenv 15.1.0.

First layer:
 - `python3 -m venv venv0`
 - `virtualenv -p python3 virt0`

Second layer:
 - `./venv0/bin/python3 -m venv venv0-venv1`
 - `./virt0/bin/python3 -m venv virt0-venv1`
 - `virtualenv -p venv0/bin/python3 venv0-virt1`
 - `virtualenv -p virt0/bin/python3 virt0-virt1`

The broken case is using Python's stdlib `venv` to create a virtual environment using a python interpreter that lives within a virtual environment created by `virtualenv`, as you can see below.

```bash
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

In this case, when using pip it will silently use the underlying `virtualenv`-based virtual environment!

```bash
$ source virt0-venv1/bin/activate
$ which python3
<cwd>/virt0-venv1/bin/python3
$ python3 -m pip --version
pip 20.2.2 from <cwd>/virt0/lib/python3.6/site-packages/pip (python 3.6)
```
