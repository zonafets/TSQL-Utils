/*  leave this
    l:see LICENSE file
    g:utility
    k:import,csv
    o:130902\s.zaglio: sp__csvio
    o:130902\s.zaglio: sp__csvio_on
    v:121205.1000\s.zaglio: done test into table and #table
    r:121130\s.zaglio: improved import of bigger files
    r:121118\s.zaglio: load csv into a table
*/
CREATE proc sp__csv_import
    @path nvarchar(1024) = null,
    @tbl sysname = null,
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    @e_msg nvarchar(2000)               -- used for big raiserror msgs

-- ======================================================== params set/adjust ==
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''),
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end,
    @path=nullif(@path,'')

-- ============================================================== declaration ==
declare
    @run bit,
    @tmp nvarchar(4000), @size int,
    @fmt sysname,
    @ls int,
    @l int,@i int,@row int,@col smallint,@j int,
    @cmd sysname,@hr int,@adodbstream int,
    @sep nvarchar(1),@q nvarchar(1),
    @qlf nvarchar(2),@qcr nvarchar(2),@qsep nvarchar(2),@qsp nvarchar(2),
    @txt nvarchar(max),@cc nvarchar(2),@qq nvarchar(2),
    @dq bit,                            -- double quote marker
    @ncols int,                         -- counter of max n cols
    @crlf nvarchar(2),
    @flds nvarchar(4000),
    @nflds int,
    @noh bit,
    @d datetime,
    @tbl_id int,                        -- test existance
    @end_declare bit

create table #sp__csv_import_fld(
    row int,col smallint,
    pos int,ln int,dq bit,
    primary key(row,col)
    )

create table #sp__csv_import_text(txt nvarchar(max))

-- =========================================================== initialization ==
select
    @noh=charindex('|noh|',@opt),
    @sep=',',@q='"',@qq=@q+@q,@qlf=@q+lf,@qcr=@q+cr,@qsep=@q+@sep,@qsp=@q+' ',
    @ls=-1,
    @dq=0,
    @fmt='utf-8',
    @crlf=crlf,
    @tbl_id=case
            when left(@tbl,1)='#'
            then object_id('tempdb..'+quotename(@tbl))
            else object_id(quotename(@tbl))
            end,
    @flds=dbo.fn__flds_of(@tbl,',',null),
    @ncols=0,@nflds=0,
    @end_declare=1
from fn__sym()
select @nflds=dbo.fn__str_count(@flds,',')

-- ======================================================== second params chk ==
if @path is null goto help

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

/*
    @fmt    is the format of source file; by default is "utf-8"
            Other format are gived from constants acecpted by
            adodb.stream "charset" property.
    @ls     line separator (default -1 for CRLF else 10 for LF or 13 for CR)
            Unfortunatelly, MSSQL generates log that are incompatibile with
            this (or after too many tests I have not found one good)
            In that case the old xp_cmdshell "type ..." work well.
*/

-- drop table #buffer

if @path like '%[%]temp[%]%'
    begin
    exec sp__get_temp_dir @tmp out
    select @path=replace(@path,'%temp%',@tmp)
    if @dbg=1 exec sp__printf 'path:%s',@path
    end

if @path like '%..%' raiserror('worked protection against hackers :-)',16,1)

select @size=4000

if @dbg=1 exec sp__elapsed @d out,'init stream'

select @cmd='ADODB.Stream'
exec @hr = sp_oacreate @cmd, @adodbstream out
if @hr!=0 goto dispose
select @cmd='Type'
exec @hr = sp_oasetproperty  @adodbstream ,@cmd,2 -- text
if @hr!=0 goto dispose
select @cmd='charset'
exec @hr = sp_oasetproperty  @adodbstream ,@cmd,@fmt
if @hr!=0 goto dispose
select @cmd='LineSeparator'
exec @hr = sp_oasetproperty  @adodbstream ,@cmd,@ls
if @hr!=0 goto dispose
select @cmd='Open'
exec @hr = sp_oamethod  @adodbstream , @cmd, null
if @hr!=0 goto dispose
select @cmd='LoadFromFile'
exec @hr = sp_oamethod  @adodbstream , @cmd, null, @path
if @hr!=0 goto dispose
select @cmd='ReadText'

insert #sp__csv_import_text
exec @hr = sp_oamethod  @adodbstream , @cmd, null

if @hr!=0 goto dispose
exec @hr = sp_oadestroy @adodbstream
select @adodbstream=null

if @dbg=1 exec sp__elapsed @d out,'after load'

-- parse file
select top 1 @txt=txt,@l=len(@txt) from #sp__csv_import_text
select
    @i=charindex(@q,@txt)+1,    -- search first open quote
    @j=@i,
    @row=1,
    @col=1

if @i=1 raiserror('no open quote found',16,1)

if @dbg=1 exec sp__printf 'qsep=%s  l=%d  nflds=%s',@qsep,@l,@nflds

while (@i<@l and @i>0)
    begin
    /*  1. load file into nvarchar(max)
        2. if format ",
        3. scan for 1st "
        4. scan for next " and take 2 chars
        5. if "" skip 2 and goto 4
        6. if ", store, next field, skip 2 and goto 4
        7. if "#13 or "#10 new line                                         */

    select @i=@i+1                  -- skip open quote
    select @i=charindex(@q,@txt,@i) -- search next quote close
    if @i=0 break;                  -- file must end with last quote
    select @cc=substring(@txt,@i,2)
    -- exec sp__printf 'r=%d c=%d j=%d i=%d, cc=%s',@row,@col,@j,@i,@cc
    if @cc=@qq                      -- skip double quote
        begin
        select @i=@i+1,@dq=1
        continue                    -- skip inner quote
        end
    if @cc=@qsep or @cc=@qcr or @cc=@qlf or @cc=@qsp    -- new row
        begin
        insert #sp__csv_import_fld(row,col,pos,ln,dq)
        select @row,@col,@j,(@i-@j),@dq
        if @cc!=@qcr and @cc!=@qlf
            select @col=@col+1,@dq=0
        else
            begin
            -- exec sp__printf 'ncols=%d, col=%d',@ncols,@col
            if @ncols<@col select @ncols=@col
            if @ncols!=@col
                raiserror(
                    'different number of cols in row %d',
                    16,1,@row
                    )
            if @row=1
                begin
                if @ncols>999
                    raiserror('max 999 rows admitted',16,1)
                if @nflds=0 select @nflds=@ncols
                if @nflds!=@ncols
                    begin
                    select @e_msg='number of source cols(%d) '
                                 +'differ from destination(%d)'
                    raiserror(@e_msg,16,1,@ncols,@nflds)
                    end
                end
            select @row=@row+1,@col=1,@dq=0
            end
        select @j=0
        end

    -- search next open quote
    select @i=@i+1                  -- skip close quote
    select @i=charindex(@q,@txt,@i) -- search next open quote
    select @j=@i+1                  -- mark start of field
    end -- scan loop

if @j>1 raiserror('file do not correclty end with a quote',16,1)

if @dbg=1 exec sp__elapsed @d out,'after parsing'

if @dbg>0
    select
        *,
        case dq when 0
        then substring(@txt,pos,ln)
        else replace(substring(@txt,pos,ln),@qq,@q)
        end as fld
    from #sp__csv_import_fld

-- sp__csv_import 'c:\shared_folders\backup_db\csv_test.txt',@opt='noh',@dbg=1
-- drop table csv_test
-- sp__csv_import 'c:\shared_folders\backup_db\csv_test.txt',@tbl='csv_test'
-- select * from csv_test -- select * from #t
-- truncate table csv_test  -- drop table #t
-- select top 0 * into #t from csv_test --alter table #t drop column [last col]
-- truncate table #t
-- sp__csv_import 'c:\shared_folders\backup_db\csv_test.txt',@tbl='#t',@dbg=1
if @flds is null
    select @flds=isnull(@flds+',','')
                +case @noh
                 when 0
                 then replace(substring(@txt,pos,ln),@qq,@q)
                 else 'c'+dbo.fn__format(col,'0',len(@ncols))
                 end

    from #sp__csv_import_fld
    where row=1


-- Pivot table
select @txt='
%insert%
select %alias%   -- [1] as a,[2] as b,...
%into%
from (
    select
        row,col,
        case dq when 0
        then substring(txt,pos,ln)
        else replace(substring(txt,pos,ln),'''+@qq+''','''+@q+''')
        end as fld
    from #sp__csv_import_fld,#sp__csv_import_text
    '+case @noh when 1 then '' else 'where row>1' end +'
    ) as src
pivot
(
    max(fld) for col in (%col%) -- [1],[2],...
) as result
'

select @txt=replace(@txt,
                    '%alias%',
                    dbo.fn__str_exp('[%idx%] as [%%]',@flds,',')
                    )
select @txt=replace(@txt,'%col%',dbo.fn__str_exp('[%idx%]',@flds,','))

if not @tbl is null
    begin
    if @tbl_id is null
        select @txt=replace(
                        replace(@txt,'%insert%',''),
                        '%into%',
                        'into '+@tbl
                        )
    else
        select @txt=replace(
                        replace(@txt,'%insert%','insert into '+@tbl),
                        '%into%',
                        ''
                        )
    end
else
    select @txt=replace(replace(@txt,'%insert%',''),'%into%','')

if @dbg=1 exec sp__printsql @txt
exec(@txt)

if @dbg=1 exec sp__elapsed @d out,'after pivot and out'

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.
if @hr!=0
    begin
    declare @source nvarchar(255)
    declare @description nvarchar(255)

    exec @hr = sp_oageterrorinfo @adodbstream, @source out, @description out
    raiserror('ole error (%s;%s;%s)',16,1,@cmd,@source,@description)
    end

if not @adodbstream is null
    begin
    exec @hr = sp_oadestroy @adodbstream
    select @adodbstream=null
    end

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    load a csv file and store it into a table

Notes
    - this replace old SP__CSV_IN
    - actually import only comma separated values closed into double quotes

Parameters
    @path   is the path of the file; if end with \ will loaded all .csv/.txt
    @tbl    is the name of destination table; if not exists will be created
            if not specified will used the name of file without extension
            can be a #temp table
    @opt    options
            noh     no header in the first line

See
    sp__csv_export

Examples
    sp__csv_import "%temp%\customers.txt
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
if not @adodbstream is null
    begin
    exec @hr = sp_oadestroy @adodbstream
    select @adodbstream=null
    end

exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__csv_import