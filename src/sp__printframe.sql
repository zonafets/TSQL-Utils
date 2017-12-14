/*  leave this
    l:see LICENSE file
    g:utility
    todo: manage @level
    v:130605\s.zaglio: removed sp__printf parameters
    v:110701\s.zaglio: added @out
    v:110624\s.zaglio: added multiline comment
    v:100723\s.zaglio: added code style
    v:100626\s.zaglio: print a well visible comment also in code style
    t:sp__printframe 'this is a test'
    t:sp__printframe 'this is a code comment',#
    t:
        create table #src(lno int identity,line nvarchar(4000))
        exec sp__printframe '#src test',@out='#src'
        select * from #src
        drop table #src
*/
CREATE proc sp__printframe
    @format nvarchar(4000)=null,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null,
    @level smallint=null,
    @out sysname   =null
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0
if @format is null goto help

declare
    @r nvarchar(4000),@l1 nvarchar(240),@l2 nvarchar(240),@l int,
    @crlf nvarchar(2),@l3 nvarchar(240), @l4 nvarchar(240)

-- select @crlf=crlf from fn__sym()

if @out is null
    begin

    -- multiline comment
    if charindex('%s',@format)=0 and charindex('%d',@format)=0
    and not @p1 is null
        begin
        exec sp__printf ''
        exec sp__printf '-- ##########################' -- col 30
        exec sp__printf '-- ##'
        select @r='-- ## '+@format
        if not @p1 is null select @l1='-- ## '+convert(nvarchar(240),@p1)
        if not @p2 is null select @l2='-- ## '+convert(nvarchar(240),@p2)
        if not @p3 is null select @l3='-- ## '+convert(nvarchar(240),@p3)
        if not @p4 is null select @l4='-- ## '+convert(nvarchar(240),@p4)
        exec sp__printf @r
        if not @l1 is null exec sp__printf @l1
        if not @l2 is null exec sp__printf @l2
        if not @l3 is null exec sp__printf @l3
        if not @l4 is null exec sp__printf @l4
        exec sp__printf '-- ##'
        exec sp__printf '-- ########################################################' -- col 60
        goto ret
        end

    if coalesce(@p1,'')!='#'
        begin
        select @format='-- ## '+@format
        select @r=dbo.fn__printf(@format,@p1,@p2,@p3,@p4,null,null,null,null,null,null)
        exec sp__printf ''
        exec sp__printf '-- ##########################' -- col 30
        exec sp__printf '-- ##'
        exec sp__printf @r
        exec sp__printf '-- ##'
        exec sp__printf '-- ########################################################' -- col 60
        end
    else
        begin
        -- sp__printframe 'this is a code comment',#

        select @r='exec sp__printframe '''+
                  dbo.fn__printf(@format,@p1,@p2,@p3,@p4,null,null,null,null,null,null)+
                  ''' -- ##'
        select @l=len(@r)
        select @l1='-- '+replicate('#',@l-3)
        select @l2='-- ################'+replicate(' ',@l-21)+'##'

        exec sp__printf ''
        exec sp__printf @l1
        exec sp__printf @l2
        raiserror(@r,10,1)
        exec sp__printf @l2
        exec sp__printf @l1
        end
    end -- @out is null
else
    begin
    -- out to table
    if @out!='#src' or object_id('tempdb..#src') is null goto err_out

    -- multiline comment
    if charindex('%s',@format)=0 and charindex('%d',@format)=0
    and not @p1 is null
        begin
        insert #src(line) select '-- ##########################' -- col 30
        insert #src(line) select '-- ##'
        select @r='-- ## '+@format
        if not @p1 is null select @l1='-- ## '+convert(nvarchar(240),@p1)
        if not @p2 is null select @l2='-- ## '+convert(nvarchar(240),@p2)
        if not @p3 is null select @l3='-- ## '+convert(nvarchar(240),@p3)
        if not @p4 is null select @l4='-- ## '+convert(nvarchar(240),@p4)
        insert #src(line) select @r
        if not @l1 is null insert #src(line) select @l1
        if not @l2 is null insert #src(line) select @l2
        if not @l3 is null insert #src(line) select @l3
        if not @l4 is null insert #src(line) select @l4
        insert #src(line) select '-- ##'
        insert #src(line) select '-- ########################################################' -- col 60
        goto ret
        end

    if coalesce(@p1,'')!='#'
        begin
        select @format='-- ## '+@format
        select @r=dbo.fn__printf(@format,@p1,@p2,@p3,@p4,null,null,null,null,null,null)
        insert #src(line) select ''
        insert #src(line) select '-- ##########################' -- col 30
        insert #src(line) select '-- ##'
        insert #src(line) select @r
        insert #src(line) select '-- ##'
        insert #src(line) select '-- ########################################################' -- col 60
        end
    else
        begin
        -- sp__printframe 'this is a code comment',#

        select @r='exec sp__printframe '''+
                  dbo.fn__printf(@format,@p1,@p2,@p3,@p4,null,null,null,null,null,null)+
                  ''' -- ##'
        select @l=len(@r)
        select @l1='-- '+replicate('#',@l-3)
        select @l2='-- ################'+replicate(' ',@l-21)+'##'

        insert #src(line) select ''
        insert #src(line) select @l1
        insert #src(line) select @l2
        insert #src(line) select @r
        insert #src(line) select @l2
        insert #src(line) select @l1
        end

    end

goto ret

-- =================================================================== errors ==

err_out:    exec @ret=sp__err 'Only #src is admitted or %s not found',@proc,@p1=@out

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    print a well visible comment also in code style

Parameters
    @format     same of sp__printf (%s,%d,%t are markers for @p1,@p2...)
    @p1         if @p1 is ''#'', the title is printed in code style
                to integrate into code

Examples
'
exec sp__printf '\n    sp__printframe ''this is a test''               -- produces:'
exec sp__printframe 'this is a test'
exec sp__printf '\n    sp__printframe ''this is a code comment'',#     -- produces:'
exec sp__printframe 'this is a code comment',#

select @ret=-1
ret:
return @ret
end -- sp__printframe