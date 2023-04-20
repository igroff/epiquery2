--parameters:
--@myJson json myJson
--@datetime datetime datetime

select @datetime [datetime]

SELECT value FROM OpenJson(@myJson);
