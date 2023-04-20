--parameters:
--@myJson json myJson
--@xyz varchar xyz

SELECT value FROM OpenJson(@myJson);

select value from string_split(@xyz,',')