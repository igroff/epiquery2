--parameters:
--@message varchar message
--@myJson json array

IF ISJSON(@myJson) > 0
    SELECT 'Valid Json' AS 'Result';

declare @myArray table (value varchar(32))

insert into @myArray
SELECT value
FROM OpenJson(@myJson)

select count(*) as ct from @myArray





