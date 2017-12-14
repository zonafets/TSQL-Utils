/*  leave this
    l:see LICENSE file
    g:utility
    v:120416\s.zaglio: @sentence to nvarchar(max)
    v:110823\s.zaglio: better help
    v:110512\s.zaglio: a bug near @tbl
    v:110415\s.zaglio: a bug on inline multiple tags
    v:110316\s.zaglio: a remake
    v:091029\s.zaglio: management of error within len(token)>16 now 32
    v:091025\s.zaglio: a little remake using @tables; @tbl is changed to bit and used fixed name #vars
    v:091022\s.zaglio: expanded limits of 16 tockens if @tbl not null
    v:091016.2000\s.zaglio: added help
    v:090918\s.zaglio: restyle
    v:090610\S.Zaglio: added @sep
    v:090123\S.Zaglio: added @null parameters for null constant for null values
    v:090121\S.Zaglio: added imput data from table (##)
    v:090113\S.Zaglio: added max tokens check
    v:081219\S.Zaglio: added @inject for special sql replaces
    v:081214\S.Zaglio: changed again convert to 126 because damn MSSQL
    v:081212\S.Zaglio: changed convert date from 126 to 120 because MSSQL QA 2k-2k8 don't accept T
    v:081130\S.Zaglio: added auto convertion of datetime values to iso8601
    v:081016\S.Zaglio: removed @from and added check for multi or single tokens
    v:081007\S.Zaglio: added @from as costant source for  @sentence
    v:080909\S.Zaglio: if @tokens is null become eq to @sentence and work like a fn__str_join
    v:080815\S.Zaglio: added spaces trim on tokens to allow well format coding and @v9-@v16
    v:080807\S.Zaglio: added @test,@v5-7 and correcteed bug in convertion
    v:080729\S.Zaglio: multiple replace
*/
CREATE proc [dbo].[sp__str_replace]
    @sentence nvarchar(max)=null out,
    @tokens nvarchar(4000)=null,
    @v1 sql_variant=null,
    @v2 sql_variant=null,
    @v3 sql_variant=null,
    @v4 sql_variant=null,
    @v5 sql_variant=null,
    @v6 sql_variant=null,
    @v7 sql_variant=null,
    @v8 sql_variant=null,
    @v9 sql_variant=null,
    @v10 sql_variant=null,
    @v11 sql_variant=null,
    @v12 sql_variant=null,
    @v13 sql_variant=null,
    @v14 sql_variant=null,
    @v15 sql_variant=null,
    @v16 sql_variant=null,
    @test bit=null,
    @dstyle tinyint=null,
    @inject bit=null,
    @tbl bit=null,
    @null sysname=null,
    @sep sysname=null,
    @dbg bit=null
as
begin
set nocount on

declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

if @sentence is null goto help

select
    @test   =isnull(@test,0),
    @dstyle =isnull(@dstyle,126),
    @inject =isnull(@inject,0),
    @tbl    =isnull(@tbl,0),
    @null   =isnull(@null,''),
    @sep    =isnull(@sep,'|'),
    @dbg    =isnull(@dbg,0)

declare
    @n int,@i int, @v sql_variant,@tl smallint, -- max token name length
    @vv nvarchar(4000),@t sysname, @single bit,
    @token nvarchar(4000)

-- a id bigger than 16 cause mssql warning about rec size>8096 byes
declare @tkns table (
    id int identity(1,1) primary key,
    tkn nvarchar(4000),
    val sql_variant null
    )

select @tl=32

if @tokens='#vars'
    insert @tkns(tkn,val)
    select id,[value] from #vars

if @tbl=1
    insert @tkns(tkn,val)
    select id,[value] from #vars v
    -- 110512\s.zaglio
    -- join dbo.fn__str_table(@tokens,@sep) t
    -- on t.token=v.id

if @tokens!='#vars' and @tbl!=1
    begin
    insert @tkns(tkn)
    select left(token,@tl)
    from dbo.fn__str_table(@tokens,@sep) t
    if exists(select null from @tkns where len(tkn)>@tl) goto err_tln
    update @tkns set val=@v1 where id=1
    update @tkns set val=@v2 where id=2
    update @tkns set val=@v3 where id=3
    update @tkns set val=@v4 where id=4
    update @tkns set val=@v5 where id=5
    update @tkns set val=@v6 where id=6
    update @tkns set val=@v7 where id=7
    update @tkns set val=@v8 where id=8
    update @tkns set val=@v9 where id=9
    update @tkns set val=@v10 where id=10
    update @tkns set val=@v11 where id=11
    update @tkns set val=@v12 where id=12
    update @tkns set val=@v13 where id=13
    update @tkns set val=@v14 where id=14
    update @tkns set val=@v15 where id=15
    update @tkns set val=@v16 where id=16
    end -- if @tokens!='#vars' and @tbl!=1

-- convertion to string
update @tkns set
    val=case
        when SQL_VARIANT_PROPERTY(val,'BaseType')='datetime'
        then convert(nvarchar(48),val,@dstyle)
        else convert(nvarchar(4000),coalesce(val,@null))
        end


if @dbg=1 select * from @tkns

if @sentence!='#src'
    update @tkns set
        @sentence=replace(@sentence,tkn,convert(nvarchar(4000),val))
    from @tkns
else
    begin
    declare cs cursor local forward_only for
        select lno,line
        from #src
    open cs
    while 1=1
        begin
        fetch next from cs into @i,@vv
        if @@fetch_status!=0 break
        select
            @vv=replace(@vv,tkn,convert(nvarchar(4000),val))
        from @tkns t
        where charindex(t.tkn,@vv)>0
        update #src set line=@vv where lno=@i
        end -- while of cursor
    close cs
    deallocate cs
    end -- #src replace

if @test=1
    begin
    if @sentence!='#src'
        print @sentence
    else
        exec sp__print_table '#src'
    end
goto ret
-- =================================================================== errors ==
err_tln:    exec sp__err 'token name greater than %s',@proc,@p1=@tl
            goto ret
-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    replace pieces of sentence

Parameters
    @sentence   the source to replace (or #src)
    #src        alternative source (lno int identity,line nvarchar(4000))
    @tokens     the pieces to replace separated by @sep (or #vars)
    @v1..@v16   the values relative to tokens
    #vars       alternative tokens (id nvarchar(16),value sql_variant)
    @test       print the result
    @dstyle     date style (default 126)
    @inject     inject the values into ''''
    @tbl        if 1, uses content of #vars instead of @v1..v16
    @null       replace nulls values with this
    @sep        by default "|", is the separator of tokens
    @dbg        debug mode; print some info for developer

Examples:

    declare @r real,@d datetime
    select @r=10.12345678,@d=getdate()
    exec sp__str_replace    ''%s;r=%r;d=%d'',
                            ''%r|%d|%s'',
                            @r,@d,''replaced''
                            ,@test=1

    exec sp__str_replace    ''this %is% the %n%st %tst%'',
                            ''%is%|%n%|%tst%'',
                            ''is'',1  ,''test''
                            ,@test=1

    table mode 1:
        create table #vars (id nvarchar(16),value sql_variant)
        declare @st sysname
        insert #vars values(''%a%'',''STEFANO'')
        insert #vars values(''%d%'',getdate())
        set @st=''my name is %a% and now is %d% local time''
        exec sp__str_replace @st out,''%a%|%d%'',@tbl=1,@test=1
        drop table #vars

    table mode 2:
        create table #src  (lno int identity,line nvarchar(4000))
        create table #vars (id nvarchar(16),value sql_variant)

        insert #src(line) select ''this %is% test''
        insert #src(line) select ''of the %dt%''
        insert #vars values(''%is%'',''is'')
        insert #vars values(''%dt%'',getdate())
        exec sp__str_replace ''#src'',''#vars'',@test=1,@dbg=1
        drop table #vars
        drop table #src

'
select @ret=-1

ret:
return @ret
end -- sp__str_replace