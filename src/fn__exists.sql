/*  leave this
    l:see LICENSE file
    g:utility
    v:100919.1000\s.zaglio: added type "fl" for field
    v:100612\s.zaglio: better code; NB: for files/dir, use sp__dir
    v:091001\S.Zaglio: added management of #t
    v:090915\S.Zaglio: forwarded fkey test from rkey to fkey on sysfkeys
    v:090815\S.Zaglio: a remake using object_id()
    v:090813\S.Zaglio: manage of [quoted] names
    v:090705\S.Zaglio: added management of global temp tables
    v:090130\S.Zaglio: added db management in names (loosed type check)
    v:081217\S.Zaglio: added multiple check with and or or and (nolock)
    v:081207\S.Zaglio: added foreign keys check if @type='fk'
    v:081021\S.Zaglio: added owner
    v:080808\S.Zaglio: check existance of obj of type. If type is null, find any
    t:print object_id('dbo.sysobjects')
    t: print dbo.fn__exists('[sysobjects]',null) -->1
    t: print dbo.fn__exists('sysobjects',null) -->1
    t: print dbo.fn__exists('dbo.sysobjects',null) -->1
    t: print dbo.fn__exists('dbo.sysobjects','X') -->1
    t: print dbo.fn__exists('sys.sysobjects',null) -->1
    t: print dbo.fn__exists('nothing.sysobjects',null) -->0
    t: print dbo.fn__exists('sysobjects,syscolumns',null) -->1 and condition
    t: print dbo.fn__exists('sysobjects|sysnothing',null) -->1 or condition
    t: print dbo.fn__exists('sysobjects,sysnothing',null) -->0 and condition
    t: create table ##test(id int) print dbo.fn__exists('##test',null) exec sp__drop '##test'   -- 1
    t: create table #test(id int) print dbo.fn__exists('#test',null) exec sp__drop '#test'      -- 1
    t:
        create table test_fn_exists(a int)
        print dbo.fn__exists('test_fn_exists',default)
        print dbo.fn__exists('test_fn_exists.a','fl')
        print dbo.fn__exists('test_fn_exists.notex','fl')
        drop table test_fn_exists
*/
CREATE function [dbo].[fn__exists](
    @objects nvarchar(4000),
    @type nvarchar(2) = null
    )
returns tinyint
as
begin
-- note: object_id uses dbo as default when not specified
-- select @objects='[sysobjects]',@type=null    <---- BE CAREFULL
--  declare @dbg bit,@objects nvarchar(4000), @type nvarchar(2) select @objects='test_fn_exists.a',@dbg=1

declare @stdout table(lno int identity,line nvarchar(4000))
declare
    @exists bit,
    @owner sysname,
    @obj sysname,@fld sysname,
    @cmd nvarchar(1024),
    @true tinyint,@false tinyint,
    @db sysname,@id int,
    @n int,
    @cond nchar(1)

select
    @true=1,@false=0,
    @cond=','

if @objects is null goto ret
if charindex(',',@objects)=0 set @cond='|'  -- OR condition

set @n=dbo.fn__str_count(@objects,@cond)
while (@n>0 and
        (@exists is null
        or (not (@exists=0 and @cond=',')   -- exists and exists...
            and not (@exists=1 and @cond='|')   -- exists or exists
            )
        )
    )
    begin
    -- dbo.fn__sql_unquotename not possibile because can be [dbo].[...]

    select  @obj=dbo.fn__str_at(@objects,@cond,@n),
            @fld=null,@id=null,
            @n=@n-1

    -- special case for field
    if @type='fl' select @fld=parsename(@obj,1),@obj=parsename(@obj,2)

    -- special case for temp
    if left(@obj,1)='#' or left(@obj,2)='[#'
        select @obj='tempdb..'+@obj

    select @id=object_id(@obj)
    if @type='fk' -- foreign keys existance
        begin
        if exists(
                select null from dbo.sysforeignkeys fk with (nolock)
                where fkeyid=@id
                )
            set @exists=@true
        else
            select @exists=@false
        end
    else
        begin
        if not @id is null
            begin
            select @exists=@true
            if not @fld is null
            and not exists(
                select top 1 null
                from syscolumns
                where id=@id and [name]=@fld
                ) select @exists=@false
            end -- obj.fld
        else
            select @exists=@false
        end -- normal obj
    end -- while

ret:
-- print @exists
return @exists
end -- fn__exists