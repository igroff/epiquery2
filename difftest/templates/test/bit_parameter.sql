/*
  executionMasks:
    a_valid_bitmask: 1
*/
--@zeroIsFalse bit
--@oneIsTrue bit
--@stringFalseIsFalse bit
--@stringTrueIsTrue bit
--@stringFalseIsFalseNoCase bit
--@stringTrueIsTrueNoCase bit

select @zeroIsFalse [zeroIsFalse],
  @oneIsTrue [oneIsTrue],
  @stringFalseIsFalse [stringFalseIsFalse],
  @stringTrueIsTrue [stringTrueIsTrue],
  @stringFalseIsFalseNoCase [stringFalseIsFalseNoCase],
  @stringTrueIsTrueNoCase [stringTrueIsTrueNoCase]

