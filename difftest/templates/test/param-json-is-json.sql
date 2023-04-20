--parameters:
--@myJson json myJson


IF ISJSON(@myJson) > 0
    SELECT 'Valid Json' AS 'Result';

SELECT type
FROM OpenJson(@myJson, '$.apples') WITH (type VARCHAR(32) '$');



