/*  leave this
    l:see LICENSE file
    g:utility
    k:job,status,history,number,execution
    v:131127.1100\s.zaglio: added name
    v:131126.1000\s.zaglio: added from_date
    v:131122\s.zaglio: modified and integrated into sp__job_status
    r:131117\s.zaglio: return history grouped by number of execution
    t:select * from fn__job_status('%',30*24*60,default)
    t:select * from fn__job_status('%status%',30*24*60,'fle')
    t:select * from fn__job_status('%',30*24*60,'fle')
*/
CREATE function fn__job_status(
    @jobs nvarchar(4000),       -- jobs separated by |
    @mins int,                  -- minutes back for search (default 24h)
    @opt sysname
    )
returns @rs table (
    row         int null,
    id          uniqueidentifier not null,
    name        sysname not null,
    run_date    int not null,
    run_time    int not null,
    from_time   int not null,
    dt_ss       int null,
    err         bit null,
    n           int null
    )
as
begin
-- ================================================================== options ==

declare
    -- options
    @fle bit    -- from last error

-- ===================================================================== init ==

select @mins=isnull(@mins,7*24*60)
if not @opt is null
    select
        @opt='|'+@opt+'|',
        @fle=charindex('|fle|',@opt)
else
    select @fle=0

-- ===================================================================== data ==

declare @data table (
    instance_id int,
    row         int null,
    id          uniqueidentifier not null,
    name        sysname not null,
    stp         int not null,
    err         bit null,
    run_date    int not null,
    run_time    int not null,
    dt_ss int null,
    primary key (instance_id desc)
    )

insert @data(instance_id,row,id,name,stp,err,run_date,run_time,dt_ss)
select
    instance_id,
    row =
        row_number() over(order by sjh.job_id,run_date,run_time,sjh.step_id),
    id = sjh.job_id,
    name = j.name,
    stp = sjh.step_id,
    err = cast(case when sjh.sql_severity>10 then 1 else 0 end as bit),
    run_date,
    run_time,
    dt_ss =
        run_duration%100+(run_duration/100%100*60)+
        (run_duration/10000%100*3600)
-- select top 10 *
from msdb..sysjobhistory sjh (nolock)
join msdb..sysjobs j on j.job_id=sjh.job_id
join fn__str_split(@jobs,'|') on name like token
and run_date>cast(convert(sysname,dateadd(mi,-@mins,getdate()),112) as int)
and sjh.server=@@servername

/* outcome running job
if 0!=(select top 1 stp from @data)
    insert @data
    select top 1 instance_id+1,row,id,name,0,err,run_date,run_time,dt_ss
    from @data
*/

-- ================================================================= outcomes ==

declare @outcomes table(
    orow        int null,
    row         int null,
    id          uniqueidentifier not null,
    name        sysname not null,
    stp         int not null,
    err         bit null,
    run_date    int not null,
    run_time    int not null,
    dt_ss int null
    )

insert @outcomes
select
    orow=row_number() over(order by row),
    row,id,name,stp,err,run_date,run_time,dt_ss
from @data
where stp=1

-- =================================================================== ranges ==

declare @ranges table(
    rrow int null,
    l    int null,
    r    int null
    )

insert @ranges
select
    rrow=row_number() over(order by a.row),
    a.row as l,
    isnull(b.row-1,(select max(row) from @data d where d.id=a.id)) as r
from @outcomes a
left join @outcomes b on isnull(b.orow,a.orow+1)=a.orow+1

-- ========================================================== groups of steps ==

declare @grps table(
    row         int null,
    id          uniqueidentifier not null,
    err         bit null,
    rrow        int null
    )

insert @grps
select data.row,data.id,data.err,ranges.rrow
from @data data
join @ranges ranges
on data.row between ranges.l and ranges.r

-- ===================================================================== runs ==

declare @runs table(
    row  bigint null,
    id   uniqueidentifier not null,
    err  bit null,
    rrow bigint null
    )

insert @runs
select
    min(row) as row,id,
    cast(sum(cast(err as int)) as bit) err,
    rrow
from @grps
group by id,rrow

-- ========================================================== history summary ==

declare @his table(
    row         bigint null,
    id          uniqueidentifier not null,
    name        sysname not null,
    run_date    int not null,
    run_time    int not null,
    dt_ss int null,
    err         bit null
    )

insert @his(row,id,name,run_date,run_time,dt_ss,err)
select
    row=row_number() over (order by data.row),
    data.id,data.name,data.run_date,data.run_time,data.dt_ss,
    runs.err
from @data data
join @runs runs on data.row=runs.row

-- ================================================================== headers ==

declare @heads table(
    row  bigint null,
    hrow bigint null
    )

insert @heads
select cur.row,hrow = row_number() over (order by cur.row)
from @his cur
left join @his prev on cur.row = prev.row+1
where prev.err != cur.err or prev.id != cur.id or cur.row=1

-- ================================================================= his grps ==

declare @his_grps table(
    row         int null,
    id          uniqueidentifier not null,
    run_date    int not null,
    run_time    int not null,
    dt_ss int null,
    err         bit null,
    hrow        bigint null
    )

insert @his_grps(row,id,run_date,run_time,dt_ss,err,hrow)
select  his.row,his.id,his.run_date,his.run_time,his.dt_ss,his.err,
        hrow = (select max(hrow)
                from @heads heads
                where heads.row <= his.row)
from @his his

-- =============================================================== record set ==

if @fle=0
    insert @rs(row,id,name,run_date,run_time,from_time,dt_ss,err,n)
    select
        his.row,his.id,his.name,
        his.run_date,his.run_time,err.run_time,his.dt_ss,
        his.err,err.n
    from @his his
    join (
        select max(row) row,err,count(hrow) n,min(run_time) run_time
        from @his_grps
        group by hrow,err
        ) err on his.row=err.row
    order by row desc
else
    insert @rs(row,id,name,run_date,run_time,from_time,dt_ss,err,n)
    select
        his.row,his.id,his.name,his.run_date,
        his.run_time,err.run_time,his.dt_ss,
        his.err,err.n
    from @his his
    join (
        select max(row) row,err,count(hrow) n,min(run_time) run_time
        from @his_grps
        group by hrow,err
        ) err on his.row=err.row
    join (
        select id,max(row) row
        from @his_grps
        where err=1
        group by id,err
        ) fle on his.id=fle.id and his.row>=fle.row
    order by row desc

return
end -- fn__job_status