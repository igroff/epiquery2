--parameters:
--@my_object_1 json my_object_1
--@my_object_2 json my_object_2

SELECT name, planet FROM OpenJson(@my_object_1) 
    WITH (
        name VARCHAR(7) '$.name',
        planet varchar(20) '$.planet'

    );

SELECT value FROM OpenJson(@my_object_2);

SELECT  count(*) as my_array_count 
FROM    OpenJson(@my_object_2);

