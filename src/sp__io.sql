/*  leave this
    l:see LICENSE file
    g:utility,io
    v:120515\s.zaglio: total revision
    v:120514\s.zaglio: support I/O between files and application
*/
CREATE proc sp__io
    @cod nvarchar(4000) = null,
    @id  int            = null out,
    @opt sysname        = null,
    @dbg int            = 0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if @cod is null goto help

-- ============================================================== declaration ==
declare
    @end_declare bit

-- =========================================================== initialization ==
select
    @end_declare=1

-- ======================================================== second params chk ==

-- ===================================================================== body ==

-- drop table iof drop view iof_list
if object_id('iof') is null
    begin
    create table iof(
        tid     tinyint,
        id      int identity(-2147483648,1) constraint pk_iof primary key,
        rid     int not null,           -- parent
        pid     int null,
        flags   smallint not null,
        wrong       as cast(iof.flags & dbo.fn__flags('F') as bit),
        processed   as cast(iof.flags & dbo.fn__flags('G') as bit),
        idx     int null,               -- line number
        txt     nvarchar(4000) not null,-- file/path/... name or line of text
        dt      datetime null           -- date of file
        )
    create index ix_iof_rid on iof(rid,id)
    end -- io_files

-- tids
select @id=null
select @id=id from tids,iof where iof.tid=tids.grp and txt=@cod
if @@rowcount=0
    begin
    -- truncate table iof
    -- sp__io null,'test'
    begin tran
    insert iof(tid,rid,flags,txt)
    select tids.grp,0,0,@cod from tids
    select @id=@@identity
    update iof set rid=@id where id=@id
    commit
    end

goto ret

-- =================================================================== errors ==
err_nid:
exec @ret=sp__err 'code for tid must be specified',@proc
goto ret

err_trn:
exec @ret=sp__err 'inside transaction',@proc
goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    support I/O between files and application
    If not exists, create/alter table "iof" and other structures.
    See flags.iof.* for other specifics.

Parameters
    @id out     id of record
    @cod        name of group
    @opt        options (not used)

Examples
    -- insert a new grp record and/or return the id is already exists
    -- if necessary, creare/update structures
    exec sp__io @id=@gid out,@cod=''my group''

    -- store a text file

    -- header
    insert iof(tid,rid,flags,txt)
    select tids.[file],@gid,0,''filename.ext'' from tids
    select @fid=@@identity

    -- rows
    insert iof(tid,rid,flags,idx,txt)
    select tids.code,@fid,0,txt.lno,txt.line
    from tids,#src as txt
    order by txt.lno

    -- list files of my group
    select txt from tids,iof where iof.tid=tids.file and iof.rid=@gid
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__io