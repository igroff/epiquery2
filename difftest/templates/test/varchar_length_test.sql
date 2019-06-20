--parameters:
--@consultationIds varchar consultationIds
DECLARE @output_length int, @output_type varchar(16)

select  @output_length = varchar_test_data_length
from (select top (1) len(@consultationIds) as varchar_test_data_length
from 	sys.objects) T;

select @output_type = substring(st.text, charindex('varchar(', st.text),12)
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
WHERE cp.cacheobjtype = N'Compiled Plan'
AND cp.objtype IN (N'Prepared')
AND text like  '%varchar_test_data_length%'

SELECT @output_type as output_type, @output_length as output_length;

--# delete any plans associated with this test
declare @sql nvarchar(max), @plan_handle varbinary(64)
declare  curs_plans cursor for
select plan_handle
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
WHERE cp.cacheobjtype = N'Compiled Plan'
AND cp.objtype IN (N'Prepared')
AND text like  '%varchar_test_data_length%'

OPEN curs_plans
FETCH NEXT FROM curs_plans INTO @plan_handle
WHILE @@FETCH_STATUS = 0
BEGIN

	set @sql = N'DBCC FREEPROCCACHE (' + UPPER(MASTER.dbo.Fn_varbintohexstr(@plan_handle)) + ')'
	print @sql
	exec sp_executesql @sql

	FETCH NEXT FROM curs_plans INTO @plan_handle
END
CLOSE curs_plans
DEALLOCATE curs_plans



