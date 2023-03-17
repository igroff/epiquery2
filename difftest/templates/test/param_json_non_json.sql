--parameters:
--@myJson json myJson

IF ISJSON(@myJson) = 0
    SELECT 'Not Valid Json' AS 'Result';


