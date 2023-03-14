--parameters:
--@myJson varchar myJson


IF ISJSON(@myJson) > 0
    SELECT 'Valid Json' AS 'Result';
ELSE
    SELECT 'Not Valid Json' as 'Result';

SELECT @myJson as 'Result2';


