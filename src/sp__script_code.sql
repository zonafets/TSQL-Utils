/*  leave this
    l:see LICENSE file
    g:utility,script
    v:130729.1000\s.zaglio:managed #objs
    v:121012\s.zaglio:option to remove top comments
    v:120730\s.zaglio:adding support for #src_def
    v:120717\s.zaglio:replaced {tab} with 4 spaces
    v:120622\s.zaglio:added related option
    v:120504\s.zaglio:managed drop option of history
    v:120213\s.zaglio:around @obj as hex value
    v:120207\s.zaglio:adapted to new log_ddl
    v:111028\s.zaglio:script of trigger into sp_execute
    v:110721\s.zaglio:added debug to test anomalous chars as � that boh... and used fn__ntext_to_lines
    v:110628\s.zaglio:added scripting of trigger on db
    v:110406\s.zaglio:on mssql2k5 uses sys.sql_modules instead of syscomments
    v:110329\s.zaglio:added @obj as # to script old revisions and removed @out
    v:100919.1000\s.zaglio:more compatible mssql2k
    v:100919\s.zaglio:strip end comments to not duplicate it ad every sp__script
    v:100411\s.zaglio:added synonym
    v:100328\s.zaglio: version 3.0 of scripting utility for views,proc,function,trigrs
    t:sp__script_code 'sp__script_code',@dbg=1
    t:sp__script 'sp__script_code'
    t:sp__script_ole 'sp__script_code'
    t:sp__script_code 'obj_not_exist'
    t:sp__script 'sp__script',@dbg=1
    t:
        create table #src(lno int identity,line nvarchar(4000))
        exec sp__Script_code 'sp__Script_code'
        select * from #src order by lno
        drop table #src
    t:
        create proc test as print 'hello'
        exec sp__script_code 'test'
        drop proc test
    t:
        create synonym stest for sp__script_code
        exec sp__script_code 'stest'
        exec sp__script 'stest'
        drop synonym stest
    t:sp__script_code 230   -- sp__script_trace
    t:sp__Script_code 'tr__script_trace_db'
    t:sp__script_code 'sp__script_code',@dbg=1,@opt='notcm'
*/
CREATE proc [dbo].[sp__script_code]
    @obj sysname=null,
    @opt sysname=null,
    @ntext ntext=null,  -- dummies
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select  @proc=object_name(@@procid),@ret=0,
        @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
if @obj is null goto help

if @dbg=1 exec sp__printf '-- sp__script_code(%s,%s)',@obj,@opt

-- unicode test:"日本"

declare
    @lno_begin int,@lno_end int,
    @id int,@db sysname,@sch sysname,@sch_id int,
    @obj_ex sysname,@obj_in sysname,
    -- @def bit,                        -- must stay in sp__Script
    @end_declare bit

declare @src table(lno int identity primary key,line nvarchar(4000))

declare
    @buf nvarchar(4000),@line nvarchar(4000),
    @s int,@k int,@i int,@n int,@j int,@old nvarchar(4000),
    @c nchar(1),@cr nchar(1),@lf nchar(1),@crlf nvarchar(2),
    @xtype nvarchar(4),@spaces varchar(4),@tab char(1)

select @cr=cr,@lf=lf,@crlf=crlf,@tab=tab,@spaces='    ' from fn__sym()

if left(@obj,1)='#'
    begin
    select top 1 @ntext=definition
    from tempdb.sys.sql_modules with (nolock)
    where object_id=object_id('tempdb..'+@obj)
    print @ntext
    goto fill_src
    end

select
    -- @def=isnull(object_id('tempdb..#src_def'),0),
    @db =parsename(@obj,3),
    @sch=parsename(@obj,2),
    @obj=parsename(@obj,1)
if @db is null select @db=db_name()
select @sch=[name],@sch_id=id from dbo.fn__schema_of(@obj)
select @obj_ex  = quotename(@db)+'.'
                + coalesce(quotename(@sch),'')+'.'
                + quotename(@obj)

-- copy from syscomments or from log_ddl into internal table
if left(@obj,2)='0x'
    begin
    select @id=dbo.fn__hex2int(@obj)
    select @ntext=txt
    from tids,log_ddl tbl
    where tbl.tid=tids.code and tbl.id=@id
    -- sp__script 80000007 -- sp__script_history
    if @@rowcount=0 goto err_nof
    end
else
    begin
    -- get type
    select @id=id,@xtype=xtype from sysobjects where [name]=@obj

    -- if is a synonym
    if @xtype='SN'
        begin

        insert #src(line)
        select 'create '+lower(sy.type_desc)+' '
               +sc.name + '.' + sy.name -- as synonym_name
               +' for '+sy.base_object_name
        from sys.synonyms sy
        join sys.schemas  sc on sc.schema_id = sy.schema_id
        where sy.[object_id] = @id
        goto ret
        end -- synonym

    if @id is null select @id=object_id from sys.triggers where [name]=@obj
    if @id is null goto err_nof
    select top 1 @ntext=definition
    from sys.sql_modules with (nolock)
    where object_id=@id
    end -- fill @blob

-- ##########################
-- ##
-- ## fill @src
-- ##
-- ########################################################
fill_src:
insert @src(line)
select line from fn__ntext_to_lines(@ntext,0 /*remove crlf */)
update @src set line=rtrim(line)

-- remote top comments /* */
if charindex('|sqlite|',@opt)>0
or charindex('|notcm|',@opt)>0
    begin
    select @line=null
    select top 1 @line=line
    from @src
    where line like '/*%' or line like '--%'
    order by lno
    if @line like '--%'
        delete from @src
        where lno<(
            select top 1 lno from @src
            where not line like '--%'
            )
    -- NB: nested comment are not managed
    if @line like '/*%'
        delete from @src
        where lno<=(
            select top 1 lno from @src
            where line like '%*/'
            )
    end -- delete top comments

-- ########################################################

select @lno_begin=min(lno),@lno_end=max(lno)
from @src

-- strip blank line above
select top 1 @lno_begin=lno
from @src
where line!=''
and lno>=@lno_begin
order by lno

select top 1 @lno_end=lno
from @src
where line!=''
and lno<=@lno_end
order by lno desc

-- strip end comments to not duplicate it ad every sp__script
if exists(
    select top 1 null from @src
    where left(line,16)='exec sp__comment'
    and lno<=@lno_end
    order by lno desc
    )
    select top 1 @lno_end=lno from @src
    where left(line,16)!='exec sp__comment'
    and lno<=@lno_end
    order by lno desc

-- if is a trigger, require GO so we encapsulate into execute
if (@xtype='TR' and charindex('|related|',@opt)!=0)
or (left(@obj,2)='0x' and charindex('|drop|',@opt)!=0)
-- and charindex('|DROP|',@opt)=0
    begin
    -- note: this manage one single code
    update @src set
        line=replace(
                case when right(line,1)='\' -- this solve escape problem
                then line+' '
                else line
                end,'''',''''''
                )
    update @src set line='exec sp_executesql N'''+line where lno=@lno_begin
    update @src set line=line+'''' where lno=@lno_end
    end -- encapsulate

if object_id('tempdb..#src') is null
    select line
    from @src
    where lno between @lno_begin and @lno_end
    order by lno
else
    insert #src(line)
    select replace(line,@tab,@spaces)
    from @src
    where lno between @lno_begin and @lno_end
    order by lno

-- nb: charindex search into 4000 chars max
goto ret

-- =================================================================== errors ==
err_nof:    exec @ret=sp__err 'object or release %s not found',@proc,@p1=@obj
            goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope of %proc%
    script objects tha has code into syscomments(mssql2k) or sys.sql_modules(mssql2k5)
    or log_ddl

Notes
    {tab} is replaced with 4 spaces

Parameters
    @obj    is the object name
    @ntext  is for internal use
    #src    if declared store result into this otherwise output as select
    @opt    options     description
            drop        enclose code into sp_executesql statement
            related     when a trigger is under a table, code is
                        encapsulated into a sp_executesql
            notcm       do not script top comments

'


select @ret=-1

ret:
return @ret
end -- sp__script_code