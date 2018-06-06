--@makeThisNvarcharNull nvarchar
--@makeThisVarcharNull varchar
select IsNull(@makeThisNvarcharNull, 'this should be long')
select IsNull(@makeThisVarcharNull, 'this should be long')
