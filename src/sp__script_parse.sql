/*  Keep this due MS compatibility
    l:see LICENSE file
    g:utility
    r:091128\s.zaglio: added group and continued develop
    r:090921\s.zaglio: select source code of @obj withhtml
    t:sp__script_tohtml 'sp__script_tohtml'
*/
create proc [dbo].[sp__script_parse]
    @obj sysname=null,
    @dbg smallint=0                      -- enable print of debug info
as
begin
set nocount on
if @dbg>=@@nestlevel exec sp__printf 'level of debugging:%d',@@nestlevel
-- declarations
declare
    @proc sysname,      -- for sp__trace
    @msg nvarchar(4000),-- generic messages
    @sql nvarchar(4000),-- for inner sql
    @ret int,           -- return ok if 0 error if <0 or a value if >0
    @err int,           -- user for pure sql statements
    @i int,@n int,      -- generix index variables
    @timer datetime,    -- used to trace times
    @token sysname,
    @tl sysname,
    @p int,
    @in_comment_line bit,
    @in_comment bit,
    @in_string bit,
    @line nvarchar(4000),@html nvarchar(4000),
    @step int,
    @end_declare bit    -- close the declaration section so can add
                        -- a new in the middle

-- specific declarations; is better keep all on top
declare @name sysname       -- generic name/string
declare @array table (id int identity,name sysname)  -- generic list

-- initialization
select  @proc='sp__script_tohtml',
        @ret=0

-- exec sp__elapsed @timer out,'** init of sp__style: '

-- parameters check
if @obj is null goto help

/* ================================ body ================================== */
-- sp__script
create table #src (lno int identity(10,10),line nvarchar(4000))
exec sp__script @obj,@out='#src'
select @in_comment=0,@in_comment_line=0,@in_string=0,@step=10
select @i=min(lno),@n=max(lno) from #src
exec sp__printf '%s\n%s','<html>','<body>'
while (@i<=@n)
    begin
    select @line=line from #src where lno=@i
    select @i=@i+@step
    -- follows tockens
    if @line is null exec sp__printf '<br>'
    else
        begin
        select @p=null,@tl=null,@html=''
        while (@p is null or (@p!=0 and @p<len(@line)))
            begin
            select @token=null
            exec sp__token @line,@token out,@p out,@tl=@tl out,
                @in_comment_line=@in_comment_line out,
                @in_comment=@in_comment out,
                @in_string=@in_string out
            -- sp__Script 'fn__token_sql'
            if dbo.fn__token_sql(@token)=1
            -- and @in_comment=0 and @in_comment_line=0
            -- and @in_string=0
                select @html=@html+@tl+'<b>'+@token+'</b>'
            else
                select @html=@html+@tl+coalesce(@token ,'')
            -- exec sp__printf '[%s](%s)',@tl,@token
            if @token is null break
            end -- token scans
        exec sp__printf '%s<br>',@html
        end -- if not blank line
    end -- lines
exec sp__printf '%s\n%s','</body>','</html>'
drop table #src
goto ret -- end of body

/* =============================== errors ================================= */
err:        -- init of error management

/* ================================ help ================================== */
help:
exec sp__usage @proc
select @msg=null,@ret=-1    -- generic Help error

ret:     -- procedure end...is better than return
if not @msg is null
    begin
    exec sp__printf @msg
    -- exec sp__trace @msg,@last_id=@ret out,@proc=@proc
    end
return @ret
end -- proc