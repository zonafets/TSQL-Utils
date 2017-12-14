/*  leave this
    l:see LICENSE file
    g:utility
    v:100919.1000\s.zaglio:write/delete a windows registry
    t:
        exec sp__reg_write 'hklm\software\sp__reg\test','wtest',@dbg=1
        exec sp__reg_write 'hklm\software\sp__reg\test1',3,@dbg=1
        exec sp__reg_write 'hklm\software\sp__reg\test2',2.3,@dbg=1

        exec sp__reg_write 'hklm\software\sp__reg\test',null,@dbg=1
        exec sp__reg_write 'hklm\software\sp__reg',null,@dbg=1
        exec sp__reg_write 'hklm\software\sp__reg\%',null,@dbg=1
*/
CREATE proc sp__reg_write
    @key nvarchar(512)  = null,
    @val sql_variant    = null out,
    @dbg int=0
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname,  @ret int -- standard API: 0=OK -1=HELP, any=error id
select @proc='sp__reg_write', @ret=0

if @key is null goto help

-- declarations
create table #stdout (KeyExists int null)
create table #values (val sysname null, data sql_variant null)
declare @exists bit,@exists_parent bit,
        @k nvarchar(512),@v sysname,@t sysname,
        @r sysname,@vs nvarchar(4000),@vn int,@vb varbinary(4000)

select @t=convert(sysname,sql_variant_property(@val,'BaseType'))
select @t=case @t
          when 'tinyint'    then 'reg_dword'
          when 'int'        then 'reg_dword'
          when 'smallint'   then 'reg_dword'
          when 'bigint'     then 'reg_sz'
          when 'nvarchar'   then 'reg_sz'
          when 'varchar'    then 'reg_sz'
          when 'varbinary'  then 'reg_binary'
          when 'binary'     then 'reg_binary'
          else 'reg_sz'
          end

if @t='reg_sz'      select @vs=convert(nvarchar(4000),@val)
if @t='reg_dword'   select @vn=convert(int,@val)
if @t='reg_binary'  select @vb=convert(varbinary(4000),@val)

-- initialization
select @r=[root],@k=[key],@v=[value] from dbo.fn__reg_parse(@key)
select @key=@k+'\'+@v

-- ===================================================================== body ==
insert #stdout exec master..xp_regread @r,@k
select top 1 @exists_parent=KeyExists from #stdout

if @exists_parent=1
    begin
    insert #values exec master..xp_regenumvalues @r,@k
    if @dbg=1 select * from #values
    select @exists=isnull((select top 1 1 from #values where val like @v),0)
    end
else
    select @exists=0

if @dbg=1 exec sp__printf 'exists: "%s":%d; "%s":%d',@key,@exists,@k,@exists_parent

if @val is null
    begin
    if @dbg=1 exec sp__printf 'delete from %s val %s\%s or key %s',@r,@k,@v,@key
    if @exists=1 and @v!='%' exec master..xp_regdeletevalue @r,@k,@v
    else
        begin
        if @v='%' and @exists_parent=1 exec master..xp_regdeletekey @r,@k
        else goto err_nokey
        end
    end
else
    begin
    if @t='reg_sz'      exec master..xp_regwrite @r,@k,@v,@t,@vs
    if @t='reg_dword'   exec master..xp_regwrite @r,@k,@v,@t,@vn
    if @t='reg_binary'  exec master..xp_regwrite @r,@k,@v,@t,@vb
    if @dbg=1 exec sp__printf 'write reg %s\\%s\%s of type "%s" with "%s"',@r,@k,@v,@t,@val
    end

goto ret

-- =================================================================== errors ==
err_nokey:  select @ret=1   goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    write/delete a registry of windows

Parameters
    @key    name of key with key_value; key_value can be % for delete of the key
    @val    value (will be converted into string or int or bigint)
            if NULL, delete the key; if return NULL, the key do not exists
    return  -1 for help, 0 if ok, 1 if key/val not exists

Examples
    -- delete the key
    sp__reg_write ''hklm\software\microsoft\windows nt\currentversion\aedebug\debugger'',null

    -- read the key value and store it in @val. If @val is null the key do not exists
    sp__reg_read ''hklm\software\microsoft\windows nt\currentversion\aedebug\debugger'',@val out
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__reg_write