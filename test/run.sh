#! /usr/bin/env bash

function run_tests(){
  DIR=$1
  TEST_NAME=$2
  for test in $DIR/*;
  do
    if [ -d ${test} ]; then
      run_tests ${test} ${TEST_NAME}
    else
      test_file=${test}
      test_name=`basename ${test}`
      [ -n "${TEST_NAME}" ] && [ "${test_name}" != "${TEST_NAME}" ] && continue
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
# we need to be sure we start with no results otherwise we just end up 
# potentially testing the results of the last run again
rm -rf test/results/*
run_tests ./test/tests $1
