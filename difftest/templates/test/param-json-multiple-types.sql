--parameters:
--@myJson json myJson
--@datetime datetime datetime
--@threshold float threshold
--@cmIds nvarchar cmIds
--@amount decimal amount
--@autoInvoice bit autoInvoice
--@cmid int cmid


SELECT value as v,@datetime as datetimes,@threshold as thresold ,@cmIds as cmdids
,@amount as amount,@autoInvoice as autoInvoice,@cmid as cmids 
from openjson(@myJson) 

