--parameters:
--@myJson json myJson

IF NOT ISJSON(@myJson) > 0
    SELECT 'Not Valid Json' AS 'Result';
