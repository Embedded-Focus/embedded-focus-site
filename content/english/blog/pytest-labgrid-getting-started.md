---
title: "Streamline Integration Testing with pytest and labgrid (Part 1)"
authors: ["Rainer Poisel"]
lastmod: 2023-05-31T21:36:18+02:00
draft: false
toc: true
comments: true
image: "header.jpg"
tags: ["pytest", "labgrid"]
categories: ["QA", "Testing"]
canonical: "https://honeytreelabs.com/posts/pytest-labgrid-getting-started/"
---

We will demonstrate how to implement system and integration tests effectively using the pytest and labgrid frameworks.

<!--more-->


## Introduction {#introduction}

In the realm of software development, ensuring the reliability and functionality of a project's targets is paramount. System and integration testing, the practice of evaluating the interaction between various software and hardware components, plays a pivotal role in validating the overall system's performance. However, setting up and managing device under test (DUT) environments for integration testing can be a complex and time-consuming process.

Thankfully, [pytest](https://docs.pytest.org/) and [labgrid](https://labgrid.readthedocs.io/) come to the rescue as a dynamic duo, offering a robust solution to streamline the setup and execution of integration tests on DUTs. With pytest, a popular testing framework for Python, and labgrid, an open-source tool for managing and controlling DUTs, developers gain a powerful toolkit to automate and orchestrate their system and integration testing processes.

In this blog post series, we will dive into the world of pytest and labgrid, exploring how these tools can work harmoniously together to create an efficient and scalable environment for running integration tests on DUTs. We will walk through the essential concepts, demonstrate practical use cases, and highlight the benefits that this combination brings to your testing workflow.

Our first part demonstrates the simplest scenario possible. While labgrid allows for setting up a distributed infrastructure, we will focus on using only some of labgrid's convenience functionality to interact with DUTs directly. By the end of this blog post, you will have a solid foundation to implement pytest and labgrid in your integration testing workflow, enabling you to optimize your DUT setup, automate testing processes, and achieve robust and reliable results. So, let's embark on this journey and unlock the potential of these powerful tools together!


## Setting up pytest {#setting-up-pytest}

The installation procedure for `pytest` depends on the environment used. My development environment is based on [pyenv](https://github.com/pyenv/pyenv) and [pyenv-virtualenv](https://github.com/pyenv/pyenv-virtualenv). Please see the profound readme files of these projects to get them installed. When trying things out, I create a new environment like this:

```shell
# install python version of choice
pyenv install 3.11.3
# create virtualenv called `pytest-labgrid` based on this version
pyenv virtualenv 3.11.3 pytest-labgrid
# activate new virtualenv for the current shell session
pyenv shell pytest-labgrid
# make sure to also look into `pyenv local` to have `direnv` like behavior
```

When having the newly installed environment activated, one can install `pytest` by running:

```shell
pip install pytest
```

Let's verify the installation by creating one of the most simple test cases possible, i.e. a file called `test_example.py` with the following contents:

```python
import logging

def test_example():
    logging.info("My first testcase")
    assert True, "must always pass"
```

Running `pytest` with this file results in the following output:

```shell
pytest -sv
========================================== test session starts ==========================================
platform linux -- Python 3.11.3, pytest-7.3.1, pluggy-1.0.0 -- /home/user/.pyenv/versions/3.11.3/envs/pytest-labgrid/bin/python3.11
cachedir: .pytest_cache
rootdir: /home/user/project
collected 1 item

test_example.py::test_example PASSED

=========================================== 1 passed in 0.01s ===========================================
```

We don't see the logging message yet. Resist the temptation to make outputs with `print()`. While it is still possible to do that, with the logging module we are not only more flexible. One also works with it according to the [specifications](https://docs.pytest.org/en/7.1.x/how-to/logging.html) of the pytest project. In order to activate logging on the console, create a `pytest.ini` file in the root directory of your tests with the following contents:

```ini
[pytest]
log_cli = true
log_cli_level = INFO
```

Now, we are ready to trace effectively:

```shell
pytest -sv
========================================================== test session starts ===========================================================
platform linux -- Python 3.11.3, pytest-7.3.1, pluggy-1.0.0 -- /home/user/.pyenv/versions/pytest-labgrid/bin/python3.11
cachedir: .pytest_cache
rootdir: /home/user/project, configfile: pytest.ini
collected 1 item

test_example.py::test_example
------------------------------------------------------------- live log call --------------------------------------------------------------
INFO     root:test_example.py:4 My first testcase
PASSED

=========================================================== 1 passed in 0.00s ============================================================
```

When working with `labgrid`, it is sometimes necessary to get the DUT into some state before working with it. This calls for "setup" or "teardown" functionality. The `pytest` mechanism for setUp and tearDown functionality is implemented using so called "[fixtures](https://docs.pytest.org/en/latest/explanation/fixtures.html)". These are quite powerful and, under some circumstances, can be pretty complex too. In order to run some logic before and after our test cases, we can define a fixture like this:

```python
import pytest

from typing import Iterator
import logging

@pytest.fixture(scope="session")
def myfixt() -> Iterator[int]:
    logging.info("before")
    yield 42
    logging.info("after")

def test_fixture(myfixt):
    assert myfixt == 42
```

The `myfixt` fixture is run before all tests and after all tests. It consists of two parts: all that comes before the first `yield` statement is executed before test cases, and everything that comes after it is executed after all tests (there are different scopes that can be used, but for simplicity reasons, we are using a `session` scope here). Using a fixture is accomplished by some naming convention: function parameters of test functions refer to the desired fixture function names. The `pytest` framework ensures that fixtures are executed in the right order and passed to the functions that request them. Fixtures can also have a value. The value yielded by the fixture is the value the fixture takes in the test cases where it is used. This is verified here by the `assert` in the `test_fixture` function.

We now have covered all `pytest` functionality needed to work effectively with test cases using the [labgrid](https://github.com/labgrid-project/labgrid/) framework. In the next step we will install and configure it.


## Setting up labgrid {#setting-up-labgrid}

The [labgrid project](https://github.com/labgrid-project/labgrid/) is very well [documented](https://labgrid.readthedocs.io/). The documentation also contains a "Getting Started" tutorial. While finding it pretty useful to get started for complex scenarios by setting up the distributed infrastructure, it took me some time to get started with only using the convenience functionality of this really useful package. Let's get started as quickly as possible. Install `labgrid` into your development environment by running:

```shell
pip install labgrid
```

Verify the installation by checking if the labgrid pytest plugin can be found:

```shell
pytest --trace-config --collect-only
# ...
PLUGIN registered: <module 'labgrid.pytestplugin' from '/home/user/.pyenv/versions/pytest-labgrid/lib/python3.11/site-packages/labgrid/pytestplugin/__init__.py'>
# ...
setuptools registered plugins:
  labgrid-23.0.1 at /home/user/.pyenv/versions/pytest-labgrid/lib/python3.11/site-packages/labgrid/pytestplugin/__init__.py
active plugins:
    labgrid             : /home/user/.pyenv/versions/pytest-labgrid/lib/python3.11/site-packages/labgrid/pytestplugin/__init__.py
# ...
plugins: labgrid-23.0.1
collected 3 items
# ...
```

This log output indicates that the plugin was successfully registered. Let's now setup the DUT. In my case, I have a development Raspberry Pi called `raspberry-d.lan` which I can access using SSH. I enabled public key authentication on this device so that I don't have to enter the password every time (assuming a public key-pair is already available). Apart from that, password-less authentication is a basic requirement for the automatic execution of the tests. Transfer your public-key to the DUT:

```shell
ssh-copy-id root@raspberry-d.lan
```

The labgrid configuration is created in YAML format. To make the Raspberry Pi available to pytest test cases, create a file called `inventory.yaml` with the following contents:

<a id="code-snippet--labgrid inventory"></a>
```yaml
---
targets:
  main:
    resources:
      - NetworkService:
          address: raspberry-d.lan
          username: root
    drivers:
      - SSHDriver: {}
```

The `resources` are low-level items that can be used by higher-level `drivers`. In this case, we create a `SSHDriver` which is based on a `NetworkService` with an `address` and a `username` parameter. As there is only one `NetworkService` and just one `SSHDriver` we don't need to specify explicitly that there is a relation between these two. This configuration is all it takes to run commands on our target.

Create a file called `test_labgrid.py` with the following contents:

```python
from labgrid.target import Target
from labgrid.driver import SSHDriver
from labgrid.driver.exception import ExecutionError

import pytest

from typing import Iterator
import logging


@pytest.fixture(scope='session')
def shell_cmd(target: Target) -> Iterator[SSHDriver]:
    cmd = target.get_driver('SSHDriver')
    target.activate(cmd)
    yield cmd


def test_uname_system(shell_cmd: SSHDriver):
    result = '\n'.join(shell_cmd.run_check("uname -s"))
    logging.info(result)
    assert 'Linux' == result


def test_command_fails_system(shell_cmd: SSHDriver):
    with pytest.raises(ExecutionError, match='command not found'):
        shell_cmd.run_check("program does not exist and fails therefore")
```

Side note: I tend to use [Python's typing hints](https://peps.python.org/pep-0484/) where possible. This allows the language server (based on the Language Server Protocol "[LSP](https://microsoft.github.io/language-server-protocol/)"; [pyright](https://github.com/microsoft/pyright) in my case) to help me with better navigating the code as well as for showing warning/error messages in case I access something that's not available in expected types.

I will use a test filter expression `-k` to only run tests of the `test_labgrid.py` test script. We can now run these tests and verify that they are executed on a Linux system (Raspberry Pi OS). Furthermore, using the `run_check` method of the `SSHDriver` instance, failing commands will result in an `ExecutionError`. The `test_command_fails_system` test function demonstrates how to deal with the situation that such error is expected.

```shell
pytest -sv --lg-env inventory.yaml -k test_labgrid.py
================================================ test session starts ================================================
platform linux -- Python 3.11.3, pytest-7.2.2, pluggy-1.0.0 -- /home/user/.pyenv/versions/pytest-labgrid/bin/python3.11
cachedir: .pytest_cache
rootdir: /home/user/project, configfile: pytest.ini
plugins: labgrid-23.0.1
collected 4 items / 2 deselected / 2 selected

test_labgrid.py::test_uname_system    INFO: Connected to 100.86.204.114

-------------------------------------------------- live log setup ---------------------------------------------------
INFO     SSHDriver(target=Target(name='main', env=Environment(config_file='inventory.yaml')), name=None, state=<BindingState.bound: 1>, keyfile='', stderr_merge=False, connection_timeout=30.0, explicit_sftp_mode=False)(Target(name='main', env=Environment(config_file='inventory.yaml'))):sshdriver.py:174 Connected to 100.86.204.114
   INFO: Linux
--------------------------------------------------- live log call ---------------------------------------------------
INFO     root:test_labgrid.py:20 Linux
PASSED
test_labgrid.py::test_command_fails_system PASSED

========================================== 2 passed, 2 deselected in 1.40s ==========================================
```

Everything works as designed. We are now ready to write more complex tests. The labgrid [examples directory](https://github.com/labgrid-project/labgrid/tree/master/examples) is a helpful resource for possible usage scenarios of the framework. I found the [PREEMPT_RT test examples](https://github.com/labgrid-project/labgrid/blob/master/examples/shell/test_rt.py) pretty useful to get started.


## Bonus: Using direnv to set the labgrid environment {#bonus-using-direnv-to-set-the-labgrid-environment}

If you, like me, are working with a shell on different projects frequently, it is worth having a look at [direnv](https://direnv.net/). Direnv is a command-line tool and environment switcher that enhances the development workflow by automatically loading and unloading environment variables based on the current directory. It allows developers to define per-project environment configurations, making it easier to manage and switch between different sets of environment variables, such as paths, variables, or aliases, depending on the project's specific requirements. Direnv seamlessly integrates with the shell and automatically sets up the environment variables when entering a directory and reverts the changes when leaving, ensuring that the correct environment is consistently maintained throughout the development process.

In this section, we will leverage the power of `direnv` to automatically set the labgrid environment when invoking `pytest` from within a labgrid project directory. We do not have to specify the `--lg-env <...>` parameter when working with labgrid anymore for the given project. To do so, [install direnv](https://direnv.net/docs/installation.html), then create a `.envrc` file with the following contents (or add the following to your existing `.envrc`) in the root of your project:

```shell
export LG_ENV=$(pwd)/inventory.yaml
# you can also add other variables if you wish
```

Allow for using the newly created (or changed) `direnv` configuration by executing the following from the directory containing the `.envrc` file:

```shell
direnv allow .
```

Verify the availability of the `LG_ENV` variable by running:

```shell
env | grep LG_ENV
LG_ENV=/home/user/project/inventory.yaml
```

We are ready to give it a try by running the `test_uname_system` only using the `-k` filter switch:

```shell
pytest -k uname
================================================ test session starts ================================================
platform linux -- Python 3.11.3, pytest-7.2.2, pluggy-1.0.0
rootdir: /home/user/project, configfile: pytest.ini
plugins: labgrid-23.0.1
collected 3 items / 2 deselected / 1 selected

test_labgrid.py::test_uname_system
-------------------------------------------------- live log setup ---------------------------------------------------
INFO     SSHDriver(target=Target(name='main', env=Environment(config_file='/home/user/project/inventory.yaml')), name=None, state=<BindingState.bound: 1>, keyfile='', stderr_merge=False, connection_timeout=30.0, explicit_sftp_mode=False)(Target(name='main', env=Environment(config_file='/home/user/project/inventory.yaml'))):sshdriver.py:174 Connected to raspberry-d.lan
--------------------------------------------------- live log call ---------------------------------------------------
INFO     root:test_labgrid.py:19 Linux
PASSED                                                                                                        [100%]
========================================== 1 passed, 2 deselected in 1.88s ==========================================
```

Profit! It works as expected and we can easily run our tests without having to specify command-line options over and over again.


## Conclusion {#conclusion}

Throughout this blog post, we covered the basics of pytest and labgrid, guiding you through installation and demonstrating effective test implementation. We explored pytest's structure and fixtures, while labgrid empowered you to effortlessly manage DUTs and handle various testing scenarios.

Additionally, we shared a bonus chapter on setting environment variables to simplify the invocation of pytest with the labgrid plugin installed. This technique streamlines integration into existing workflows and eliminates manual configuration.

As usual, the code presented in this article is available as GitHub Gist: [here](https://gist.github.com/rpoisel/32b1edf2bba0de0e43e7cd729aa7fb13).

In conclusion, pytest and labgrid provide an exceptional framework for simplifying and enhancing system and integration testing. By leveraging the flexibility of pytest and the device management capabilities of labgrid, developers can achieve reliable testing results while minimizing setup time. Embrace their potential, unlock new testing possibilities, and elevate the quality and performance of your systems. Happy testing!
