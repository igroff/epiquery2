--parameters:
--@myJson1 json myJson1
--@myJson2 json myJson2


SELECT value FROM OpenJson(@myJson1) 

SELECT value FROM OpenJson(@myJson2)
