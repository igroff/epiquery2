# difftest-runner
difftest-runner helps run and track the output of test scripts so you can quickly
determine if things are the same as they were when you decided they were 'good'.

## NOTE!
I'm not a node app, I use npm for distribution because it's simple and
straight-forward.  I'm a collection of bash scripts, thus should run most
anywhere bash does, but that's not been verified in any way. That's not to
say there's no intention I run elsewhere, just that nothing's been done to
make it so.


### So.... What Now?
You'd be hard pressed to find something in Software Engineering that doesn't need or couldn't benefit from some automated testing.  It sucks to make a trivial change to something and not be able to have an equally trivial answer to the question "Well, I wonder if that change broke anything?".  So with that, testing is a must.  

  Testing, however can be done in a bunch of different ways. The simplest 
approach to writing a test is pretty straight forward:

* do something
* see what happens
* decide if that's good, or make changes until it is so
* record that output for later comparison

Using a test is even easier:

* remember that thing you did? do it again
* compare the output to what you decided was good (above)

This is the gist of damn near every testing framework in the world, and they
all have various approaches to all aspects of that process, and generally try
and be available in every single environment you can imagine. Here we try to
ignore how, what, and environment and focus only on facilitating the
'given something done' what does it's output look like and, does that output
look like what it used to.

#### All that is the long winded version of this
difftest-runner is a series of scripts that aim to make the execution of and collection of the output from a body of tests (scripts) easily repeatable
such that you can compare future executions to executions deemed 'good'.


### Things to Know

difftest-runner is distribted using npm.  This isn't because it's javascript,
or uses node because it's not and doesn't, but because npm is easy to use and
good at this 'package and distribute' thing.

There is a specific directory structure that difftest-runner uses, mostly you
don't have to care and can just interact with this through the commands provided
but it's good to know what the hell all this is:

    difftest 
      |-tests
      |-expected
      |-results
      |-filters

In the example, the root directory is called 'difftest' which is the default.
While it's technically possible to change this, why would we want to have that
complexity? 

* `/difftest/tests` - This directory contains the 'scripts' that are run to do
the 'testing'.  Generally I think of these items as scripts but they simply
need to be exec-able, and return some deterministic output to stdout.

* `/difftest/expected` - This is where the 'good' output of the scripts is stored
for future comparison.  Each test in the `tests/` directory should have a corresponding
file here which contains the output from the test that is considered good.

* `/difftest/results` - This is where the output of the last run of each test is
stored.  Each test in the `tests/` directory will create a file in this directory
containing the captured output from stdout and stderr from the most recent run
of the tests.

* `/difftest/filters` - This contains filters to be applied to test output to
make things that vary (like time stamps) fixed so comparison of output
is simplified.  Oh, and... If you put a filter in here named 'default' and ther is
no test specific filter, that one (the default) will be used.

difftest-runner doesn't care what your tests do, a big part of this was to create
something that worked the same regardless of implementation of the 'system under
test'. The whole point is only that test produce output on stdout and stderr,
difftest compares that to previous output.

### So how do I use it?

1. Install it 

        npm install -g difftest-runner

1. Initialize the directory you want to have tests in, I find this to be the root 
of my repository.

        difftest init

1. Make a test, currently the template test is nothing more than a stub of a 
bash script.   

        difftest create my_first_test

1. See that the test is really there
    
        difftest show tests

1. Edit the test to make it do something, this relies on the environment variable
```EDITOR``` being set.
  
        difftest edit my_first_test

1. See that it fails (we haven't defined passing yet!)
  
        difftest run

1. Check the results of the last test run for my\_first\_test

        difftest show my_first_test

1. Tell difftest that the results of the test are good

        difftest pass my_first_test

1. See what victory looks like!
  
        difftest run

### Examples
Here are some examples of actual tests from somewhere else:

difftest/tests/non_existant_doc 

    #! /usr/bin/env bash
    # vi:ft=sh
    curl -s -w "\n%{http_code}" http://localhost:8080/this/key/shouldnt/exist

difftest/expected/non_existant_doc

    {
      "message": "no document matching key"
    }
    200

difftest/tests/delete_doc

    #! /usr/bin/env bash
    # vi:ft=sh
    KEY_PATH=`uuidgen`
    curl -s http://localhost:8080/this/is/a/test/key/${KEY_PATH}
    curl -s -X PUT http://localhost:8080/this/is/a/test/key/${KEY_PATH} --data '{"name":"pants"}' -H 'Content-Type: application/json'
    curl -s http://localhost:8080/this/is/a/test/key/${KEY_PATH}
    curl -s -X DELETE http://localhost:8080/this/is/a/test/key/${KEY_PATH}
    curl -s http://localhost:8080/this/is/a/test/key/${KEY_PATH}

difftest/results/delete_doc

    {
      "message": "no document matching key"
    }{
      "message": "it's put"
    }{"name":"pants"}{
      "message": "deleted"
    }{
      "message": "no document matching key"
    }

### TODO

* allow for the creation of custom test templates
