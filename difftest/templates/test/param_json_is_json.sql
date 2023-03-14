--parameters:
--@myJson json myJson


IF ISJSON(@myJson) > 0
    SELECT 'Valid Json' AS 'Result';

declare @apples table (type varchar(32))

SELECT type
FROM OpenJson(@myJson, '$.apples') WITH (type VARCHAR(32) '$');



