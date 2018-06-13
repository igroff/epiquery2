-- select suser_name()

use master

if exists (select 1 from sys.syslogins where loginname = 'suser-test-a')
  drop login [suser-test-a]
if exists (select 1 from sys.syslogins where loginname = 'suser-test-b')
  drop login [suser-test-b]
go

create login [suser-test-a] with password = 'shitbiscuits1234!', default_database = master
create login [suser-test-b] with password = 'shitbiscuits1234!', default_database = master
go

drop user if exists [suser-test-a]
drop user if exists [suser-test-b]

create user [suser-test-a] for login [suser-test-a]
create user [suser-test-b] for login [suser-test-b]