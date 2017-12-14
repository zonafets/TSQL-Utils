/*  leave this
    l:see LICENSE file
    g:utility
    v:110916\s.zaglio:added special case with @usr='' and @comment=''
    v:110824\s.zaglio:added @usr
    v:110325\s.zaglio:return buildin string for scripts
    t:select dbo.fn__script_buildin(getdate(),default,default,default)
    t:select dbo.fn__script_buildin(getdate(),0,'s.zaglio','test')
    t:select dbo.fn__script_buildin(getdate(),1,'','')
    t:sp__find 'fn__script_buildin'
*/
CREATE function fn__script_buildin(
    @dt datetime,
    @time int,
    @usr sysname,
    @comment sysname
    )
returns sysname
as
begin
declare @s sysname
select @s=
    convert(sysname,@dt,12)+
    case
    when isnull(@time,1)=1
    then '.'+left(replace(convert(sysname,@dt,8),':',''),4)
    else ''
    end+
    case
    when isnull(@usr,'')='' and isnull(@comment,'')=''
    then ''
    else '\'+isnull(@usr,system_user)+
         ':'+isnull(@comment,'%unspecified comment%')
    end

return @s
end -- fn__script_buildin