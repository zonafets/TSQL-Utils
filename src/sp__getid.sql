/*  leave this
    l:see LICENSE file
    g:utility
    v:080817\S.Zaglio: complete alternativelly id or name
    t:
        declare @id int,@ido sysname
        select @ido=convert(sysname,object_id('sysobjects'))
        exec sp__getid @ido out,'sysobjects','name','id',@dbg=1
        if @ido is null print 'not found by id'
        else print @ido
        exec sp__getid @ido out,'sysobjects','name','id',@id_only=0,@dbg=1
        if @ido is null print 'not found by id'
        else print @ido
        select @ido='sysobjects'
        exec sp__getid @ido out,'sysobjects','name','id',@dbg=1
        if @ido is null print 'not found by name'
        else print @ido
*/
CREATE proc sp__getid
    @param sysname=null out,
    @table sysname=null,
    @name sysname=null,
    @id sysname=null,
    @id_only bit=1,
    @dbg bit=0
as
begin
set nocount on
declare @r int
exec @r=sp__chknulls @param,@table,@name,@id
if @r=1 goto help

declare @sql nvarchar(4000)
if isnumeric(@param)=1
    begin -- verify anyway that exists
    if @dbg=1 and @id_only=1 print 'id->id'
    if @dbg=1 and @id_only=0 print 'id->name'
    if @id_only=1 select @sql='select @id=convert(sysname,%id%) from %tbl% where %id%=convert(int,%param%)'
    else select @sql='select @id=%name% from %tbl% where %id%=convert(int,%param%)'
    exec sp__str_replace @sql out,'%id%|%tbl%|%name%|%param%',@id,@table,@name,@param
    exec sp_executesql @sql,N'@id sysname out',@id=@param out
    end
else
    begin -- get id from name
    if @dbg=1 print 'name->id'
    select @sql='select @id=convert(sysname,%id%) from %tbl% where %name%=''%param%'''
    exec sp__str_replace @sql out,'%id%|%tbl%|%name%|%param%',@id,@table,@name,@param
    exec sp_executesql @sql,N'@id sysname out',@id=@param out
    end

goto ret
help:
exec sp__usage 'sp__getid'
ret:
end -- proc