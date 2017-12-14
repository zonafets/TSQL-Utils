/*  leave this
    l:see LICENSE file
    g:utility
    v:080918\S.Zaglio: originally from http://www.sqldbatips.com/showcode.asp?ID=3
*/
CREATE procedure sp__top_waits
(
   @interval nchar(8) = '00:00:30',   -- time between snapshots in seconds (1-59)
   @showall  int = 1                 -- show all waits longer than this value
)
as
/*
   Uses snapshot of waits to determine what's waiting longest
   Some help with wait_type can be found at
   http://support.microsoft.com/default.aspx?scid=kb;en-us;Q244455
   Best reference found to date at
   http://sqldev.net/misc/WaitTypes.htm
*/
set nocount on

   create table #waits
   (
      runid               int identity(1,1)    NOT NULL,
      wait_type           sysname              NOT NULL,
      requests            float(53)            NOT NULL,
      wait_time           float(53)            NOT NULL,
      signal_wait_time    float(53)            NOT NULL,
      CONSTRAINT PK_waits PRIMARY KEY CLUSTERED
         (runid,wait_type)
   )

   insert #waits
   exec('dbcc sqlperf(waitstats)')

   waitfor delay @interval

   insert #waits
   exec('dbcc sqlperf(waitstats)')

   select a.wait_type,(b.requests-a.requests) as 'requests',
          (b.wait_time-a.wait_time) as 'wait_time',
          (b.signal_wait_time-a.signal_wait_time) as 'signal_wait_time'
   from   #waits a
   join   #waits b
   on     a.wait_type = b.wait_type and b.runid>a.runid
   where  (b.wait_time-a.wait_time) >= CAST(@showall as float(53))
   and    a.wait_type not in ('WAITFOR', 'SLEEP', 'RESOURCE_QUEUE', 'Total')
   order by wait_time desc
   option(KEEPFIXED PLAN)

   drop table #waits

return