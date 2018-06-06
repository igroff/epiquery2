--@varcharParam varchar
--@nvarcharParam nvarchar
--@varcharParam2 varchar varcharParam3
--@nvarcharParam2 nvarchar varcharParam4
select
  IsNull(@varcharParam, 'varcharParam was null') [One],
  IsNull(@nvarcharParam, 'nvarcharParam was null') [Two],
  IsNull(@varcharParam2, 'varcharParam was null') [Three],
  IsNull(@nvarcharParam2, 'nvarcharParam was null') [Four]
