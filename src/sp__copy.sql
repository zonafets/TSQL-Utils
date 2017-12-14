/*  keep this for MS compatibility
    l:see LICENSE file
    g:utility
    v:100203\s.zaglio:  added -t in bcp call coz' sql2k5 compatibility
    v:100202\s.zaglio:  added quotes and removed -t,-q in bcp call coz' sql2k5 compatibility
    v:100111\s.zaglio:  a bug around local obj search
    v:091212\s.zaglio:  a different error report for bcp
    v:091209\s.zaglio:  added supporto for ## tables on bcp copy
    v:091206\s.zaglio:  added trust connection on bcp copy and specific error info on user rights
    v:091018\s.zaglio:  well tested version with bcp
    r:091015\s.zaglio:  added BCP extension. if @src/dsc end with .txt or .cvs is a file
    v:090812\s.zaglio:  global revision
    v:090713\S.Zaglio:  added fast restore from table_date_time to table
                        (disable triggers,not manage quoted names)
    v:090405\s.Zaglio:  revision
    v:090124\S.Zaglio:  create a local copy of a table (if @obj only specified) or copy to remote server
    t:sp__copy 'test',@dbg=1      -- backup
    t:sp__copy 'test',@b=1,@dbg=1 -- restore
    t:sp__copy 'ot04_stock','ot04_stock_uni',@u=1,@v=2,@d=0,@uid='sa',@pwd='',@dbg=1
    t:sp__copy_test_bcp
    t:
        create table test(id int identity,obj sysname)
        insert test select 'one'
        insert test select 'two'
        exec sp__copy 'test'
        drop table test
        drop table test_100111_1805
*/
CREATE proc [sp__copy]
    @src        sysname=null,       -- local obj  ( can accept wild chars as * & ?)
    @dst        sysname=null out,   -- duplicated obj or db or db.schema.obj or lnk.db or
    @r          bit=0,              -- restore from last backup (search for obj_date_time)
    @s          bit=0,              -- structure only
    @d          bit=1,              -- drop destination
    @t          bit=0,              -- enable trigger while copy
    @u          bit=0,              -- transform to unicode
    @v          tinyint=0,          -- activate verbose mode: 1=src->dst 2=more steps
    @uid        sysname=null,       -- necessary for recompiling on remote svr
    @pwd        sysname=null,       -- or on local server if we want a file compile
    @soe        bit=0,              -- stop on error
    @dbg        bit=0
as
begin
-- sp_find 'sp__copy' -- used in:sp__copyalldata_to_db,sp__create_test_db,sp__distribute,sp_copy,sp_sync_distribute,sp_trk_adjust,sp_update_dev_data
/*  after hard work, ofcourse thanks to MS politics, something go wrong. SQLDMO will be dimessed
    and in a cluster of my customer some library was badly registered.
    So I decided to downgrade this sp to more standard form even if loose performance and backward compatibility

    sp__copy -> sp__script -> tmp table -> linked server -> sp__run_script -> drop local & remote tmp table
*/
set nocount on
declare
    @proc sysname,
    @msg nvarchar(4000),@tmp nvarchar(4000),@ret int,@line nvarchar(4000),
    @crlf nvarchar(2),@i int,@n int,@j int,@step int,
    @obj sysname,@obj_to sysname,
    @dt datetime,
    @bak sysname,
    @srv sysname,@db sysname,@schema sysname,@name sysname,
    @sql nvarchar(4000),@sql1 nvarchar(4000),@sql2 nvarchar(4000),@sql3 nvarchar(4000),
    @srv_sql nvarchar(512),@copy_sql nvarchar(512),
    @ot sysname,                    -- object type
    @oc_tbl smallint,   @oc_dri smallint,   @oc_trg smallint,
    @dbgdev bit,
    @ctofile bit,                   -- compile to file
    @srv_cur sysname,
    @db_cur sysname,
    @bcp_cmd nvarchar(1024),@bcp_op nvarchar(4),@file sysname,
    @temp nvarchar(512),
    @stype nvarchar(2),@dtype nvarchar(2),@ctype nvarchar(8),
    @exp1 bit,@exp2 bit,
    @end_declare bit

declare @objs table (id int identity,name sysname, type nchar(2))
declare @objd table (id int identity,name sysname, type nchar(2))

-- init and adjust
select
    @proc='sp__copy',
    @ret=0,
    @crlf=char(13)+char(10),
    @step=10,
    @oc_tbl=1,   -- table with owner and not chk
    @oc_dri=20,  -- pkey,idx and chk
    @oc_trg=32,  -- triggers only
    @dbgdev=0,
    @srv_cur=@@servername,
    @db_cur=db_name(),
    @end_declare=0

if not (@uid is null and @pwd is null)
    begin
    select @ctofile=1
    if @dbg=1 exec sp__printf '-- will be compiled with osql'
    end

-- help
if @src is null goto help

if @dbg=1 exec sp__printf 'sp__copy @src=%s, @dst=%s',@src,@dst

-- collect objects to copy
if charindex('*',@src)>0 or charindex('?',@src)>0
    insert into @objs (name,type)
    select name,xtype from sysobjects where name like replace(replace(replace(@src,'_','[_]'),'?','_'),'*','%')
if charindex('*',@dst)>0 or charindex('?',@dst)>0
    insert into @objd (name,type)
    select name,xtype from sysobjects where name like replace(replace(replace(@dst,'_','[_]'),'?','_'),'*','%')

select @exp1=0,@exp2=0
if right(@src,4) in ('.txt','.cvs') or charindex('\',@src)>0 select @exp1=1
if right(@dst,4) in ('.txt','.cvs') or charindex('\',@dst)>0 select @exp2=1

if @exp1=1 and @exp2=0
    begin
    if @dbg=1 exec sp__printf 'source is a file'
    insert @objs (name,type) select @src,'FL'
    if left(@dst,2)='##'
        insert @objd (name,type) select @dst,'U'
    else
        insert @objd (name,type) select name,xtype from sysobjects where name=@dst
    if left(@dst,1)='#' and left(@dst,2)!='##' goto err_bcpnotmp
    end
if @exp1=0 and @exp2=1
    begin
    if @dbg=1 exec sp__printf 'destination is a file'
    if left(@src,1)='#' and left(@src,2)!='##' goto err_bcpnotmp
    if left(@src,2)='##'
        insert @objs (name,type) select @src,'U'
    else
        insert @objs (name,type) select name,xtype from sysobjects where name=@src
    insert @objd (name,type) select @dst,'FL'
    end

-- local copy
if @exp1=0 and @exp2=0
    begin
    insert @objs (name,type) select name,xtype from sysobjects where name=@src
    insert @objd (name,type) select name,xtype from sysobjects where name=@src
    end

if @dbg=1 select * from @objs s left join @objd d on s.id=d.id

if not exists(select null from @objs) goto err_noobjs


create table #src (lno int identity(10,10),line nvarchar(4000))

-- for each @obj int @objs
select @i=min(id),@n=max(id) from @objs
while (@i<=@n) and (@ret=0 or @soe=0)
    begin
    select @obj=s.name,@stype=s.type,@obj_to=d.name,@dtype=d.type
    from @objs s left join @objd d on s.id=d.id where s.id=@i

    if @obj is null goto err_objnull
    if @obj_to is null goto err_bcpnotbl

    select @i=@i+1
    select @ot=dbo.fn__object_type(@obj)

    select @ctype=case
        when @stype='FL' and @dtype in ('U')    then 'bcp<'
        when @stype in ('U') and @dtype='FL'    then 'bcp>'
        when @dst is null and @r=0              then 'bak'
        when @dst is null and @r=1              then 'res'
        else null
        end

    if @ctype is null goto err_ctype

    if @dbg=1 exec sp__printf 'sp__copy:@n=%d, @i=%d,@obj=%s,@obj_to=%s,@ctype=%s',@n,@i,@obj,@obj_to,@ctype

    if @ctype in ('bcp>','bcp<')
        begin
        -- if @db='%db%' or @svr='%svr%'
        select
            @db=@db_cur,@srv=@srv_cur
            -- 091206: ,@uid=coalesce(@uid,'sa'),@pwd=coalesce(@pwd,'')
        if @ctype='bcp>' select @bcp_op='out',@file=@obj_to,@obj=@obj
        else select @bcp_op='in',@file=@obj,@obj=@obj_to
        select @j=dbo.fn__charindex('\',@file,-1)
        if @j>0 select @temp=substring(@file,1,@j-1),@file=substring(@file,@j+1,4000)
        if @j=0 or @temp='%temp%' exec sp__get_temp_dir @temp out

        select
            @file=@temp+'\'+@file,
            @obj=case when left(@obj,1)='#' then @obj else @db+'..'+@obj end
        -- /t use space as terminator
        -- /n use native varchar
        -- /q SET QUOTED_IDENTIFIERS ON
        -- -C { ACP | OEM | RAW | code_page }
        -- -T (in upper case) trusted connection
        if @uid is null and @pwd is null
            select @bcp_cmd='bcp "%db_table%" %op% "%file%" -S "%svr%" -c -T -CACP -t'
        else
            select @bcp_cmd='bcp "%db_table%" %op% "%file%" -S "%svr%" -U "%uid%" -P "%pwd%" -c -CACP -t'
        exec sp__str_replace @bcp_cmd out,'%db_table%|%op%|%file%|%svr%|%uid%|%pwd%',
                                          @obj,@bcp_op,@file,@srv,@uid,@pwd
        if @dbg=1 exec sp__printf @bcp_cmd
        insert into #src(line)
        exec @r=master..xp_cmdshell @bcp_cmd
        if @r=0 and exists(select null from #src where line like 'Error = %') select @r=1
        if @r!=0
            begin
            exec sp__print_table '#src'
            exec sp__printf @bcp_cmd
            goto err_bcp
            end
        continue
        end -- bcp

    -- backup/restore
    if @ctype in ('bak','res')
        begin
        if @ctype='res'
            begin
            select top 1 @bak=name
            from sysobjects
            where name like @obj+'[_]______[_]____'
            and isnumeric(right(name,4))=1
            and isnumeric(substring(name,len(name)-10,6))=1
            order by substring(name,len(name)-10,128) desc
            if @bak is null
                begin
                exec sp__printf '-- no %s_yymmdd_hhnn found',@obj
                continue
                end
            -- if found a table
            exec sp__printf '-- restore %s -> %s ',@bak,@obj
            select @sql ='exec sp__triggers ''da'','''+@obj+''' '+@crlf
                        +'truncate table '+@obj+' '+@crlf
                        +'set identity_insert '+@obj+' on'+@crlf
                        +'insert into '+@obj+' select * from '+@bak+' '+@crlf
                        +'set identity_insert '+@obj+' off'+@crlf
                        +'exec sp__triggers ''ea'','''+@obj+''''
            if @dbg=1 print @sql else exec (@sql)
            if @@error!=0 select @ret=1
            continue    -- next object
            end -- if @b=1

        -- backup mode
        set @dst=@obj+'_%t'
        set @dt=getdate()
        set @dst=replace(@dst,'%t',convert(nvarchar(48),@dt,12)+'_'
                +right('00'+convert(nvarchar(2),datepart(hh,@dt)),2)
                +right('00'+convert(nvarchar(2),datepart(mi,@dt)),2))
        set @obj=dbo.fn__sql_quotename(@obj)
        set @dst=dbo.fn__sql_quotename(@dst)
        exec sp__printf '-- copy %s -> %s ',@obj,@dst
        set @sql='select * into '+@dst+' from '+@obj+' with (nolock) '
        if @dbg=1 print @sql else exec(@sql)
        if @@error!=0 select @ret=1
        continue
        end -- backup mode

    -- copy mode
    if @v>0 exec sp__printf '-- copy %s -> %s ',@obj,@dst

    /*
        1: parse names to determinate the form
        2: create the script of the source without trigger & index
            or with trigger&index if @t=1
        3: if @d=1 drop target
        4: rename or export structure
        5: if (only struct)@s=0 continue with next obj
        6: else copy data
    */
    exec sp__parse_name @dst,@srv out,@db out,@schema out,@name out
    if @srv=@@servername or @srv=dbo.fn__servername(null) select @srv=null
    if not @srv is null     -- check if remote (linked) svr exists
        begin
        if not exists (select * from master..sysservers where srvname=@srv and rpc=1)
            goto err_srv_or_rpc

        if @db is null select @db=db_name()
        -- check id remote db exists
        select @sql='select @j=count(*) from '+@srv+'.master..sysdatabases where name='''+@db+''''
        exec sp_executesql @sql,N'@n int out',@j=@j
        if @j!=1 goto err_srv_db

        -- todo: check remote schema
        end

    -- if exist a db with same name of obj, the db win
    if  @srv is null and @db is null
    and exists (select * from master..sysdatabases where name=@name) select @db=@name,@name=null

    -- check locl db existance
    if  @srv is null and not @db is null
    and not exists (select * from master..sysdatabases where name=@db) goto err_loc_db

    -- todo: check local schema

    -- drop detination
    if @d=1
        begin
        if @dbg=1 exec sp__printf '-- drop destination\nexec sp__drop ''%s''',@name
        -- more secure check
        if @obj=@name goto err_same
        if @srv is null and @dbg=0 exec sp__drop @name
        if not @srv is null goto err_nods   -- todo
        end
    else
        begin
        if @obj=@name goto err_same
        if (@srv is null and @db is null) begin
            if dbo.fn__exists(@name,null)=1 goto err_dstexist
            end
        else
            goto err_dstchk
        end -- if @d=...

    -- create script
    if @dbg=1 exec sp__printf '-- get script source'

    if @t=0
        exec sp__script @obj,'#src',@step=@step,@oc=@oc_tbl  -- script without idx and trigger
    else
        begin
        exec sp__script @obj,'#src',@step=@step,@oc=@oc_tbl
        exec sp__script @obj,'#src',@step=@step,@oc=@oc_dri
        exec sp__script @obj,'#src',@step=@step,@oc=@oc_trg
        end

    if @name!=@obj
        begin
        if @dbg=1 exec sp__printf '-- rename'
        exec sp__script_replace @obj,@name,@step=@step              -- rename indexes, trigger...
        end

    if @dbgdev=1 select * from #src order by lno

    -- to unicode
    if @u=1
        begin
        if @dbg=1 exec sp__printf '-- convert to unicode'
        exec sp__script_reduce @normalize=4
        end

    -- add change of db
    if not @db is null
        begin
        if @dbg=1 exec sp__printf '-- add change of db'
        set identity_insert #src on
        insert into #src(lno,line) select 5,'use '+@db
        set identity_insert #src off
        end

    -- if remote server, transfer src to dst server
    if not @srv is null
        begin
        select @srv_sql ='exec %srv%.%db%.%dbo%.sp_executesql '
        exec sp__str_replace @srv_sql out,'%srv%|%db%|%dbo%|%tmp%',@srv,@db,@schema,@tmp
        select @tmp='tmp_'+replace(convert(sysname,newid()),'-','_')
        select @sql =@srv_sql+
                    +'N''create table %tmp% (lno int ,line nvarchar(4000))'' '
                    +'insert into %srv%.%db%.%dbo%.%tmp% select * from #src'
        exec sp__str_replace @sql out,'%srv%|%db%|%dbo%|%tmp%',@srv,@db,@schema,@tmp
        if @dbg=1 print @sql else exec(@sql)
        end

    -- compile
    if @dbg=1
        exec sp__script '#src'
    else
        begin
        exec @ret=sp__recompile '#src',
            @tofile=@ctofile,
            @srv=@srv_cur,
            @db=@db_cur,
            @uid=@uid,@pwd=@pwd
            -- ,@dbg=1
        if @ret!=0 goto err_comptbl
        end

    -- prepare sql for copy
    select @copy_sql    ='insert into '
                        + case when not @srv is null
                          then '%srv%.' else '' end
                        + case when not @db is null
                          then '%db%.' else '' end
                        + case when not @schema is null
                          then '%schema%.' else '' end
                        +'%name% '
                        +'select * from %obj%'

    if @db is null select @sql=replace(@copy_sql,'%db%.','')
    exec sp__str_replace @copy_sql out,'%srv%|%db%|%schema%|%name%|%obj%',@srv,@db,@schema,@name,@obj

    -- if is a table, load and run index and trigger
    if @ot='U'
        begin
        -- if not structure only and not trigger while copy, copy data now
        if @s=0 and @t=0
            begin
            if @dbg=1 exec sp__printf '-- copy data without idx and trg'
            if @dbg=1
                print @copy_sql
            else
                begin
                if @v>1 exec sp__printf '-- coping data ...'
                exec(@copy_sql)
                end
            end

        if @dbg=1 exec sp__printf '-- add idx and trg'

        truncate table #src
        if @dbgdev=1 select * from #src order by lno

        exec sp__script @obj,'#src',@step=@step,@oc=@oc_dri
        exec sp__script @obj,'#src',@step=@step,@oc=@oc_trg
        if @name!=@obj exec sp__script_replace @obj,@name,@step=@step

        if @u=1 exec sp__script_reduce @normalize=4     -- to unicode
        if @dbg=1
            exec sp__script '#src'
        else
            begin
            exec @ret=sp__recompile '#src',
                @tofile=@ctofile,
                @srv=@srv_cur,
                @db=@db_cur,
                @uid=@uid,@pwd=@pwd
                -- ,@dbg=1
            if @ret!=0 goto err_compdri
            end

        -- finally copy data if with trigger on
        if @s=0 and @t=1
            begin
            if @dbg=1 print @copy_sql else
                begin
                if @v>1 exec sp__printf '-- coping data ...'
                exec(@copy_sql)
                end
            end

        end -- if ot='U'


    end -- while


drop table #src
goto ret

err_noobjs:     select @ret=-1 ,@msg='#!no object found with this name/s' goto ret
err_srv_or_rpc: select @ret=-2 ,@msg='#!no dst server found or not support rpc' goto ret
err_srv_db:     select @ret=-3 ,@msg='#!no dst db found' goto ret
err_loc_db:     select @ret=-4 ,@msg='#!no local db found' goto ret
err_nofc:       select @ret=-6 ,@msg='#!file''s compile not supported again' goto ret
err_nods:       select @ret=-7 ,@msg='#!remote drop not supported again' goto ret
err_same:       select @ret=-8 ,@msg='#!cannot copy on itself' goto ret
err_dstexist:   select @ret=-9 ,@msg='#!destination already exists, use @d=1' goto ret
err_dstchk:     select @ret=-10,@msg='#!remote destination existance not yet implemented' goto ret
err_comptbl:    select @ret=-11,@msg='#!compiling table' goto ret
err_compdri:    select @ret=-12,@msg='#!compiling dri' goto ret
err_ctype:      select @ret=-13,@msg='#!unk ctype' goto ret
err_objnull:    select @ret=-14,@msg='#!null object name' goto ret
err_bcp:        select @ret=-15,@msg='#!bcp has returned an error(NB: "unexpected EOF/Fine imprevista",'
                                    +'may depends on user''s rights in trusted(-T) connection)' goto ret
err_bcpnotbl:   select @ret=-16,@msg='#!bcp require an existing dest. table' goto ret
err_bcpnotmp:   select @ret=-17,@msg='#!bcp cannot support temp tables' goto ret

help:
select @msg ='Copy/rename a db object with or without data between dbs of linked servers\n'+
            +'Parameters:\n'
            +'\t@src    name of source object of local db\n'
            +'\t@dst    newname of local duplicate or db or svr.db or db.schema.name or\n'
            +'\t        svr.db.schema.newname\n'
            +'\nExamples\n'
            +'\tsp__copy ''mytable'',''mytable.txt''\t-- bcp to %temp%dir\file\n'
            +'\tsp__copy ''c:\test\mytable.txt'',''mytable.txt''\t-- bcp fromo file'

exec sp__usage @proc,@extra=@msg

ret:
if not @msg is null exec sp__printf @msg
return @ret
end -- proc