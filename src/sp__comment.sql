/*  leave this
    l:see LICENSE file
    g:utility
    v:100328.1000\s.zaglio: support of proc,func,view...
    v:100321\s.zaglio: support for quoted table name
    v:100228\s.zaglio: added more help
    v:100219\s.zaglio: now print if @comment is null and delete if is '';+help
    v:100129\s.zaglio: creation
    todo: using MS original methos is slow. Need to be rewritten
    t:
        create table test(t1 int,t2 int)
        exec sp__printf 'print comment of test'
        exec sp__comment 'test'
        exec sp__printf 'set comment of test'
        exec sp__comment 'test','test comment'
        exec sp__printf 'print comment of test'
        exec sp__comment 'test'
        exec sp__printf 'delete comment of test'
        exec sp__comment 'test',''  -- delete comment
        exec sp__printf 'print comment of test'
        exec sp__comment 'test'

        exec sp__comment '[test]','test comment on table'
        exec sp__comment 'test.t1','test comment on t1',@dbg=1
        exec sp__comment 'test.t2','test comment on t2'
        print dbo.fn__comment('test')
        select * from dbo.fn__comments('test')
        drop table test
    t:
        exec sp__comment 'sp__comment','test of sp comment',@dbg=1
        exec sp__comment 'sp__comment.@path','name of object to comment',@dbg=1
        print dbo.fn__comment('sp__comment.@path')
        exec sp__comment 'fn__comment.@path','name of object to comment',@dbg=1
        print dbo.fn__comment('fn__comment.@path')

        select * from dbo.fn__comments('sp__comment')
*/
CREATE proc [dbo].[sp__comment]
    @path sysname=null,
    @comment nvarchar(4000)=null out,
    @dbg bit=0
as
begin
set nocount on
declare
    @proc sysname,
    @schema sysname,@sch_type sysname,
    @obj sysname,@obj_type sysname,
    @sub sysname,@sub_type sysname,
    @old_comment nvarchar(4000),
    @msg nvarchar(4000),@id int,
    @prop sysname,@xtype nvarchar(2)

select @proc='sp__comment'

if @obj is null and @comment is null goto help

select @prop=prop,@schema=sch,@sch_type=sch_type,
       @obj_type=obj_type,@obj=obj,
       @sub_type=sub_type,@sub=sub
from dbo.fn__comment_types(@path)

if @dbg=1
    begin
    exec sp__printf 'prp=%s, sc=%s, tbl=%s, col=%s, @xt=%s, @id=%d',
                    @prop,@schema,@obj,@sub,@xtype,@id
    exec sp__printf '\t\t\t\tsct=%s, ttbl=%s, tcol=%s',
                    @sch_type,@obj_type,@sub_type
    end

select @old_comment=convert(nvarchar(4000),value )
from fn_listextendedproperty (
    @prop,
    @sch_type, @schema,
    @obj_type, @obj,
    @sub_type, @sub);

if @comment is null begin select @comment=@old_comment exec sp__printf @old_comment goto ret end

if @comment=''
    begin
    select @comment=@old_comment
    if not @comment is null
        begin
        exec sp__printf '-- deleting comment "%s" for obj "%s"',@comment,@obj
        exec sp_dropextendedproperty
            @name = @prop,
            @level0type = @sch_type, @level0name = @schema,
            @level1type = @obj_type, @level1name = @obj,
            @level2type = @sub_type, @level2name = @sub
        end
    goto ret
    end

if @old_comment is null
    exec sp_addextendedproperty
        @name = @prop, @value = @comment,
        @level0type = @sch_type, @level0name = @schema,
        @level1type = @obj_type, @level1name = @obj,
        @level2type = @sub_type, @level2name = @sub
else
    begin
    if @dbg=1 exec sp__printf '-- replace comment "%s" of "%s"',@old_comment,@obj
    exec sp_updateextendedproperty
        @name = @prop, @value = @comment,
        @level0type = @sch_type, @level0name = @schema,
        @level1type = @obj_type, @level1name = @obj,
        @level2type = @sub_type, @level2name = @sub
    end

goto ret

help:
select @msg ='Usage\n'
            +'\t@obj    can be table; table.column;(no sp,fn,view)'
exec sp__usage @proc,'
Parameters
    @obj    can be table; table.column;(no sp,fn,view)

Examples
    exec sp__comment ''table'',''comment for table''        -- se comment on table
    exec sp__comment ''table.col'',''comment for column''   -- se comment on column of table
    exec sp__comment ''table'',''new comment''              -- change comment
    exec sp__comment ''table''                              -- print comment
    exec sp__comment ''table'',''''                         -- remove comment

See also
    sp__into_tbl @tbl       show columns info of a table with comments

Note
    Actually is not possible get/set comments on view/proc/func
'

ret:
end -- proc sp__comment