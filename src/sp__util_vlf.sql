/*  leave this
    l:see LICENSE file
    g:utility
    k:virtual,log,file,transaction,grow,server,down
    v:130227\s.zaglio: mixed with sp__util_drives
    v:120906\s.zaglio: show info about virtual log files
    todo:explain fields and how to read and what to do
    c:from http://www.sqlphilosopher.com/wp/category/tsqlproblemsolving/
    t:sp__util_vlf run
*/
CREATE proc sp__util_vlf
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp
declare
    @proc sysname, @err int, @ret int -- @ret: 0=OK -1=HELP, any=error id
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if charindex('|run|',@opt)=0 goto help

-- ============================================================== declaration ==
-- declare -- insert before here --  @end_declare bit
create table #drive_info(
    letter nchar(1),
    total_mb bigint,
    free_mb bigint,
    label nvarchar(10),
    [% free] int,
    dbs nvarchar(4000),
    logs nvarchar(4000)
    )
exec sp__util_drives

-- =========================================================== initialization ==
-- select -- insert before here --  @end_declare=1
-- ======================================================== second params chk ==
-- ===================================================================== body ==

declare @databaselist table
(
      [database]        varchar(256),
      [executionorder]  int identity(1,1) not null
)

declare @vlfdensity     table
(
      [server]          varchar(256),
      [database]        varchar(256),
      [size_mb]         int null,
      [growth]          sysname null,
      [density]         decimal(7,2),
      [unusedvlf]       int,
      [usedvlf]         int,
      [totalvlf]        int,
      [drive]           sysname null,
      [drive % free]    int null
)

declare @loginforesult table
(
      [fileid]      int null,
      [filesize]    bigint null,
      [startoffset] bigint null,
      [fseqno]      int null,
      [status]      int null,
      [parity]      tinyint null,
      [createlsn]   numeric(25, 0) null
)

declare
    @currentdatabaseid      int,
    @maxdatabaseid          int,
    @dbname                 varchar(256),
    @density                decimal(7,2),
    @unusedvlf              int,
    @usedvlf                int,
    @totalvlf               int

insert into
      @databaselist
      (
      [database]
      )
select
      [name]
from
      [sys].[sysdatabases]

select
      @currentdatabaseid = min([executionorder]),
      @maxdatabaseid = max([executionorder])
from
      @databaselist

while @currentdatabaseid <= @maxdatabaseid
      begin

            select
                  @dbname = [database]
            from
                  @databaselist
            where
                  [executionorder] = @currentdatabaseid

            delete
                  @loginforesult
            from
                  @loginforesult

            insert into
                  @loginforesult
            exec('dbcc loginfo([' + @dbname + ']) with no_infomsgs')

            select
                  @unusedvlf = count(*)
            from
                  @loginforesult
            where
                  [status] = 0

            select
                  @usedvlf = count(*)
            from
                  @loginforesult
            where
                  [status] = 2

            select
                  @totalvlf = count(*)
            from
                  @loginforesult

            select
                  @density = convert(decimal(7,2),@usedvlf) / convert(decimal(7,2),@totalvlf) * 100

            insert into
                  @vlfdensity
                  (
                  [server],
                  [database],
                  [density],
                  [unusedvlf],
                  [usedvlf],
                  [totalvlf]
                  )
            values
                  (
                  @@servername,
                  @dbname,
                  @density,
                  @unusedvlf,
                  @usedvlf,
                  @totalvlf
                  )

            set @currentdatabaseid = @currentdatabaseid + 1
      end

update a set
    size_mb=size*8/1024,
    growth=case is_percent_growth
           when 1 then cast(b.growth as sysname)+'%'
           else cast(b.growth*8/1024 as sysname)+'MB'
           end,
    [drive]=letter,
    [drive % free]=[% free]
from @vlfdensity a
join sys.master_files b
on db_name(b.database_id)=a.[database]
join #drive_info c
on b.physical_name like c.letter+':%'

-- select * from sys.master_files
select
    [server],
    [database],
    [size_mb],
    [growth],
    [density],
    [unusedvlf],
    [usedvlf],
    [totalvlf],
    [drive],
    [drive % free]
from
      @vlfdensity
order by
      [density] desc

drop table #drive_info
goto ret

-- =================================================================== errors ==
/*
err_sample1:
exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param
goto ret
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    give status about db, disks and virtual log files
    (TODO: here are to write more explanation)
    (TODO: can be simplified using  DBCC SQLPERF (LOGSPACE)?)

Parameters

Examples

'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__util_vlf