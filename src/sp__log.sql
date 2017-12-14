/*  leave this
    l:see LICENSE file
    g:utility,log
    v:131014\s.zaglio: d tag into o
    v:120926\s.zaglio: autogenerate of log table
    v:110510\s.zaglio: modified idx names into %__%
    r:110422\s.zaglio: test with md5
    r:110421\s.zaglio: generalized log table
    v:110316\s.zaglio: changed @txt to ntext
    v:110213\s.zaglio: added macro %host_name%
    v:110208\s.zaglio: added update
    v:100919.1105\s.zaglio: adapted to be used for generic I/O proc
    v:100919\s.zaglio: removed a dbg info
    v:100314\s.zaglio: fast&smart new log
    o:100314\s.zaglio: sp__trace
    t:sp__log #create_table#
    t:
        exec sp__log 'test'
        exec sp__log 'test sub (%s) log','test',@n=10,@p1='xx'
    t:
        declare @rid int
        exec sp__log @rid='test',@id=@rid out
        exec sp__log 'test sub log 1',@rid
        select top 10 * from [log] order by id desc
    t: sp__log_show '%'
    t: drop table log
*/
CREATE proc sp__log
    @txt nvarchar(4000) =null,
    @ref sysname        =null,
    @n money            =null,
    @m money            =null,
    @id int             =null out,
    @pid int            =null,
    @p1 sql_variant     =null,
    @p2 sql_variant     =null,
    @p3 sql_variant     =null,
    @p4 sql_variant     =null,
    @opt sysname        =null
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0,
       @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if object_id('log','U') is null
    begin
    exec sp__printf '-- autogenerate log table'
    exec('
        create table log(
            id  int identity,
            rid int null,                   -- refer to parent
            pid int null,                   -- refer to extarnal item
            [key] as substring(c1,1,256),   -- guid or tbl.fld
            c1     varbinary(8000) null,    -- txt or msg
            c2     varbinary(256) null,     -- spid
            c3     varbinary(256) null,     -- n or table
            c4     varbinary(256) null,     -- m or field
            dt     datetime not null
            )

        alter table dbo.[log] add constraint pk__log primary key (id desc)
        create index ix__log_rid on [log](rid,id)    -- drop index [log].ix__log_rid
        create index ix__log_key on [log]([key])     -- drop index [log].ix__log_key
        create index ix__log_dt on [log](dt desc)    -- drop index [log].ix__log_dt
    ')
    end

if @txt is null and @ref is null and @id is null goto help

declare
    @log nvarchar(4000),@vb_log varbinary(8000),
    @chk bit

select
    @log=substring(@txt,1,4000),
    @chk =charindex('|chk|',@opt)

declare @rid int,@st sysname

if not @log is null
    begin
    select @log=replace(@log,'@@host_name',host_name())
    select @log=replace(@log,'@@system_user',system_user)
    select @st=convert(sysname,@@trancount)
    select @log=replace(@log,'@@trancount',@st)
    end

if not @p1 is null
    select @log=dbo.fn__printf(@log,@p1,@p2,@p3,@p4,
                               null,null,null,null,null,null)

-- get binary version
select
    @vb_log=cast(@log as varbinary(8000))

-- if a reference is specified ...
if not @ref is null
    begin
    if isnumeric(@ref)=1
        select @rid=convert(int,@ref)
    else
        begin
        -- ... find the id and ...
        select top 1 @rid=id from [log] with (nolock)
        where c1=@ref order by id desc
        -- ... if not exists, add it
        if @rid is null exec sp__log @ref,@id=@rid out
        end
    end -- get@rid

-- example: sp__log @ref='test',@id=@rid out
-- if nothing to log but @ref, return the id
if @log is null and not @ref is null
    begin
    select @id=@rid
    goto ret
    end

-- example: sp__log @hash,@ref=test,@id=@id out,@opt=chk
-- if CHK option, verify if already exists @log or @ref
if @chk=1 and not @log is null and not @rid is null
    begin
    if exists(select null from [log] with (nolock)
           where [key]=substring(@vb_log,1,256)
           and rid=@rid
           )
        begin
        select @id=null
        goto ret
        end
    end -- chk

-- example: sp__log 'sub log info 1 chg','test',@id=@id -- not null id
-- ================================================================== act_upd ==
if not @id is null
    update [log] set
        pid=isnull(@pid,pid),
        c1=isnull(@vb_log,c1),
        c3=isnull(@n,c3),
        c4=isnull(@m,c4)
    where id=@id

-- example: sp__log 'test',@id=@rid out
-- examples: sp__log 'sub log info 1','test',  @id=@id out  -- id must be null
-- ================================================================== act_ins ==
if @id is null
    begin
    if @log!='#src'     -- single log
        begin
        insert [log](   rid,   pid,
                        c1,
                        c2, c3, c4,     dt)
        select          @rid,  @pid,
                        @vb_log as c1,
                        @@spid, @n, @m, getdate()
        select @id=@@identity
        end
    else
        begin           -- log from table #src
        if @rid is null goto err_src
        insert [log](   rid,   pid,
                        c1,
                        c2, c3, c4,     dt)
        select          @rid,  @pid,
                        cast(src.line as varbinary(8000)) as c1,
                        @@spid, @n, @m, getdate()
        from #src src
        order by lno
        end
    end -- if @id is null

-- exec sp__printf 'rid:%s ref:%s',@rid,@ref

goto ret
-- =================================================================== errors ==
err_src:    exec @ret=sp__err '#src insert require a reference' goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    register info into table "log"

Parameters
    @txt    text to log
            Some macros are replaced:
                %s,%d   with @p1,@p2,@p3,@p4
                @@host_name, @@system_user, @@trancount with replative mssql functions
            if #src, copy line by line the #src content (@ref is required)

    @ref    is used for children of previous returned @id
            (if is a string, search the relative id)
    @id     if null, return the new id (used then as @ref)
            if not null, update the relative record (normally one of @n,@m field)
    @opt    options
            chk     if @ref and @txt already exists, null the @id

Notes
    This sp require the "log" table

Examples
    exec sp__log "fast raw log"

    -- structured log
    declare @id int, @rid int
    exec sp__log "test",@id=@rid out                      -- ins
    select "ref id="+cast(@rid as sysname)
    exec sp__log "sub log info 1","test",  @id=@id out    -- attach 1 by ref and get id

    exec sp__log @ref="test",@id=@rid out                 -- get ref id
    exec sp__log "sub log info 2'',@rid                    -- attach 2 by rid
    exec sp__log "%d , %s", @rid, @p1=12, @p2="XX"        -- parametrized

    exec sp__log "sub log info 1 chg","test",@id=@id      -- upd

    -- show last 10 logs
    exec sp__log_view #10

    -- store content of #src (run 2 times)
    declare @id int, @hash binary(16)
    create table #src(lno int identity,line nvarchar(4000))
    insert #src(line) select top 3 [name] from sysobjects order by id
    exec sp__md5 @hash out
    exec sp__log @hash,@ref=test,@id=@id out,@opt=chk
    if not @id is null
        begin
        exec sp__log #src,@ref=@id
        exec sp__log_view #10           -- show last 10 logs
        exec sp__log_view @hash,test    -- show specific log
        end
    else print "already_stored"
    drop table #src

'

ret:
return @ret
end -- sp__log