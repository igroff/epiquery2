#! /usr/bin/env bash

function run_tests(){
  DIR=$1
  for test in $DIR/*;
  do
    if [ -d ${test} ]; then
      run_tests ${test}
    else
      test_file=${test}
      results_file=${test%tests/*}results${test#*/tests}
      expected_file=${test%tests/*}expected${test#*/tests}
      filter_file=${test%tests/*}filters${test#*/tests}
      mkdir -p `dirname $results_file`
      if [ -f ${filter_file} ]; then
        $test_file | $filter_file > $results_file 2>&1
      else
        $test_file > $results_file 2>&1
      fi
      diff $results_file $expected_file
      if [ $? == 0 ]; then
        echo SUCCESS: $test_file
      else
        echo FAILED: $test_file
      fi
    fi
  done
}

run_tests ./test/tests
