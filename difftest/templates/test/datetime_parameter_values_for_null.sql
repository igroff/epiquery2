/*
  executionMasks:
    a_valid_bitmask: 1
*/
--@datetime datetime
--@nullDatetime datetime
--@undefinedDatetime datetime
--@stringNullDatetime datetime
--@stringUndefinedDatetime datetime


select @datetime [datetime]
select @nullDatetime [nullDatetime]
select @undefinedDatetime [undefinedDatetime]
select @stringNullDatetime [stringNullDatetime]
select @stringUndefinedDatetime [stringUndefinedDatetime]
