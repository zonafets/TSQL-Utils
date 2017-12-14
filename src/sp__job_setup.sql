/*  leave this
    l:see LICENSE file
    g:utility,utijob
    v:110305\s.zaglio:populate DB jobs from a local app table
    t:sp__job_setup @dbg=1
    t:sp__job_setup '%',@opt='dis',@dbg=1
    t:sp__job_setup '%',@tt='%db_name%|db1|a|utility|u|db3|c',@dbg=1
    t:sp__job_setup '%',@opt='run|dis',@dbg=1
*/
CREATE proc sp__job_setup
    @like   sysname=null,
    @root   sysname=null,
    @tt     nvarchar(4000)=null,
    @opt    sysname=null,
    @dbg    int=0
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname,  @ret int -- standard API: 0=OK -1=HELP, any=error id
declare @tbl sysname
select  @proc=object_name(@@procid), @ret=0,
        @opt=dbo.fn__str_quote(isnull(@opt,''),'|'),
        @tbl=convert(sysname,dbo.fn__config('jobs_setup_table','tbl_jobs_setup'))

-- ========================================================= param formal chk ==
if (@like is null and @opt='||') or object_id(@tbl) is null goto help

-- ============================================================== declaration ==
declare
    @emails sysname,@smtp sysname,@at sysname,@sql nvarchar(4000),
    @ttv sysname,@i int,@job sysname,@sp sysname,@db sysname,
    @run bit,@crlf nvarchar(2)
declare @ttt table(tkn sysname,val sysname)

-- =========================================================== initialization ==
select top 1
    @run=charindex('|run|',@opt),
    @i=charindex('|',@tt),@db=db_name(),
    @emails=convert(nvarchar(4000),dbo.fn__config('job_setup_emails',null)),
    @smtp=convert(sysname,dbo.fn__config('job_setup_smtp',
                                         dbo.fn__config('smtp_server',null))),
    @crlf=crlf
from dbo.fn__sym()

-- sp__config 'job%', sp__config 'job_setup_emails','','see sp__job_setup'
-- sp__config 'job_setup_emails',@del=1
if dbo.fn__chk_email(@emails,default)=0 goto err_email

select @ttv=left(@tt,@i-1)
select @ttv=replace(@ttv,'%db_name%',@db)
select @ttv=convert(sysname,dbo.fn__config(@ttv,@ttv))

insert @ttt
select vt.token,vs.token
from (select * from dbo.fn__str_table(substring(@tt,@i+1,4000),'|') vt
      where vt.pos%2=1) vt
join (select vs.pos-1 pos,token from dbo.fn__str_table(substring(@tt,@i+1,4000),'|') vs
      where vs.pos%2=0) vs
on vt.pos=vs.pos

if @dbg=1
    begin
    select * from @ttt
    exec sp__printf '-- @ttv=%s, @i=%s',@ttv,@i
    end
select @ttv=val from @ttt where tkn=@ttv
if @dbg=1 exec sp__printf '-- @ttv=%s',@ttv

-- ======================================================== second params chk ==

-- ===================================================================== body ==
-- initialization

create table #jobs(
    id      int,
    rif     sysname,    -- 3 chars for person
    job     sysname,    -- @root+...
    rs      sysname,    -- filter system in multi system env.
    sp      sysname,    -- stored proc name
    sched   sysname,    -- HH:MM  or HHs:MMs Nm HHe:MMe
    opt     sysname null,
    email   sysname null,
    )

exec('insert into #jobs select * from ['+@tbl+']')
if @@error!=0 goto err_tbl

update #jobs set opt=dbo.fn__str_quote(isnull(opt,''),'|')
if charindex('|dis|',@opt)>0
    update #jobs set opt=opt+'dis|'

if @dbg=1 select * from #jobs

-- ===================================================================== body ==

select
    s.id,
    isnull(@root+'_','')+job as job,
    isnull(
        replace(
            sp,
            '%ttv%',
            isnull((select tkn from @ttt where val=@ttv),@db)
            ) -- replace
        ,sp -- is null
        ) sp,
    sched, dbo.fn__str_quote(opt,'|') opt
into #steps
from #jobs s
where dbo.fn__str_in(@ttv,s.rs,'')=1
and (@like is null or job like @like)

update steps set
    sp=@db+'.dbo.'+sp
from #steps steps
where charindex('|sql|',opt)=0
and left(sp,len(@db))!=@db

-- check for existance of sp (tbl_jobs_setup)
if @dbg=1 exec sp__printf '--test existances'
select sp as sp_unk_name into #unksp from #steps
where charindex('|sql|',opt)=0
and object_id(sp) is null

if exists(select null from #unksp)
    begin
    exec sp__printf '-- list of missed sp'
    exec sp__select_astext 'select * from #unksp',@header=1
    drop table #unksp
    goto ret
    end
drop table #unksp

if @dbg=1 select * from #steps order by id

if @run=0
    exec sp__printf 'emails status to:%s\nsmtp:%s',@emails,@smtp

-- delete jobs
if isnull(@root,'')!=''
    begin
    select @job=@root+'_'+isnull(@like,'')+'#'
    exec sp__printf 'deleting "%s" jobs',@job
    if @run=1 exec sp__job @job,#
    end

if isnull(@root,'')='' and charindex('|add|',@opt)=0
    begin
    declare cs cursor local for
        select distinct job
        from #steps
    open cs
    while 1=1
        begin
        fetch next from cs into @job
        if @@fetch_status!=0 break

        select @sql=@job+'#'
        exec sp__printf 'deleting "%s" steps',@sql
        if @run=1 exec sp__job @sql,#
        end
    close cs
    deallocate cs
    end -- delete jobs

-- for each system & step of job
declare cs cursor local for
    select job,sp,sched,opt
    from #steps
    order by id
open cs
while 1=1
    begin
    fetch next from cs into @job,@sp,@at,@opt
    if @@fetch_status!=0 break

    if @run=0 or @dbg=1
        begin
        select @sql='exec sp__job\n\t@job="%s",\n\t@sp="%s",\n\t@at="%s",\n\t@opt="%s"\n\t'+
                    '@emails="%s",\n\t@smtp="%s"'
        select @sql=replace(@sql,'\n\t',@crlf)
        select @sql=replace(@sql,'"','''')
        exec sp__printf @sql,@job,@sp,@at,@opt,@emails,@smtp
        end

    if @run=1
        exec sp__job @job=@job,@sp=@sp,@at=@at,
                     @emails=@emails,@smtp=@smtp,
                     @opt=@opt

    end -- while of cursor
close cs
deallocate cs

goto ret

-- =================================================================== errors ==
err_tbl:    exec @ret=sp__err 'uncomplete of bad structure of setup table. See help',@proc
            goto ret
err_email:  exec @ret=sp__err 'bad or null email:"%s". See help',@proc,@p1=@emails
            goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    generate and regenerate jobs from ##jobs_setup_table##
    (by default "tbl_jobs_setup").

Notes
    the JOB and SP fields are the key for single step update;
    cfg "job_setup_emails,job_setup_smtp,smtp_server" are used
    for general emails

Parameters
    @root   is the brief name of the application
    @like   recreate only jobs where name like @like
    @tt     is the translate table to match TTV field (see example)
            accept macros: %db_name%, any ##cfg## or #cfg# (see sp__config)
    @opt    options
            run     execute it
            add     do not delete jobs, add or replace only
            dis     disabled to each added job
    @dbg    debug mode, 1 show info

Jobs table

    create table tbl_jobs_setup (
        id      int,            -- give the order of steps
        rif     sysname,        -- 3 chars for person
        job     sysname,        -- @root+this become the name of job
        ttv     sysname,        -- match the @tt (see example)
        sp      sysname,        -- stored proc name (%ttv% is replaced with val in @tt)
        sched   sysname,        -- HH:MM  or HHs:MMs Nm HHe:MMe
        opt     sysname null,   -- extra option passed to sp__job
        email   sysname null    -- alternative email for this step
        )

Utilities

    insert tbl_jobs_setup(id, grp, rif, job, rs, sp, sched)
    select
        id,
        grp,
        rif,
        job_Ext,
        rs,
        sp,
        sched

    update tbl_jobs_setup set
        sched=
    where id=???

    delete from tbl_jobs_setup where job=''???''


    insert tbl_jobs_setup(
                  id, rif,    job,              ttv,            sp,                             sched,              opt
            )
    --           --- ---------- ------------------ ----------------- ------------------------------ --------------------- -------------
          select  10, ''me'',   ''%job1%'',        ''*'',            ''%sp1%'',                     ''%sched1%'',         ''%opt1%''
    union select  20, ''you'',  ''%job2%'',        ''*'',            ''%sp2%'',                        ''%sched1%'',         null

Examples
    sp__job_setup @tt=''%db_name%|db1|a|utility|u|db3|c'',@dbg=1
    -- replace macro with current db_name() and if this match "db1",
    -- rows where ttv contains "a" are selected

'
if @dbg=1 exec sp__printf '-- @tbl=%s',@tbl
if not object_id(@tbl) is null
    begin
    select @sql='select * from ['+@tbl+'] order by 1'
    exec sp__select_astext @sql
    end

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__job_setup