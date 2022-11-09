/*
executionMasks:
  a_valid_bitmask: 1
*/

SELECT *, $1 as num, $1::text as num_str from generate_series(0, $1)

