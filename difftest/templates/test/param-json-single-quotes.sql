--parameters:
--@myJson1 json myJson1

SELECT test FROM OpenJson(@myJson1) WITH (test VARCHAR(32) '$.test');

SELECT value into #tmptest
FROM OpenJson(@myJson1, '$.myArray')

select value from #tmptest where value like 'dennis%'


