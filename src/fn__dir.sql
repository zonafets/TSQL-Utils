/*  leave this
    l:see LICENSE file
    g:utility
    k:sub,folder,directory,list,sub,folder,s,sp__dir,unicode
    c:from https://www.simple-talk.com/iwritefor/articlefiles/634-dboDIR.htm
    v:131015\s.zaglio: done, but abbandoned because 6-20 times slower than sp
    r:131014\s.zaglio: list content of path and sub paths
    t:select * from fn__dir('I:\i_do_not_exists',default) -- raiserror
    t:select * from fn__dir('I:\temp\',default)
    t:select * from fn__dir('I:\temp','s')
    t:select * from fn__dir('I:\temp','s|kp')
*/
CREATE function [dbo].[fn__dir](@wildcard nvarchar(4000),@opt sysname)
returns @dir table
(
    id int identity primary key,
    rid int,                -- for subdirs
    [flags] smallint,       -- if &32=32 is a <DIR>;16 is a error
    [key] nvarchar(446),    -- obj name or error string
    dt datetime,            -- creation date
    n bigint null           -- size in bytes
)
as
-- body of the function
begin
declare
    --all the objects used
    @objshellapplication int,
    @objfolder int,
    @objitem int,
    @objerrorobject int,
    @objfolderitems int,
    --potential error message shows where error occurred.
    @strerrormessage nvarchar(1000),
    --command sent to ole automation
    @command nvarchar(1000),
    @hr int,                            --ole result (0 if ok)
    @count int,@i int,
    @name nvarchar(2000),               --the name of the current item
    @path nvarchar(2000),
    @type nvarchar(2000),
    @modifydate datetime,               --the date the current item last modified
    @isfilesystem int,                  --1 if the current item is part of the file system
    @isfolder int,                      --1 if the current item is a file
    @size bigint,
    @rid int,
    @lp int,                            --len path

    -- options
    @s bit,                             --scan subdirectory
    @kp bit                             --keep root path

if len(coalesce(@wildcard,''))<2 return

if not @opt is null
    begin
    select @name='|'+@opt+'|'           --to not |||grow||| in recursion
    select @s=charindex('|s|',@name),@kp=charindex('|kp|',@name)
    end
else
    select @kp=0,@s=0

if right(@wildcard,1)='\' select @wildcard=left(@wildcard,len(@wildcard)-1)

if @kp=0 select @path=@wildcard+'\',@lp=len(@path)

select @strerrormessage = 'opening the shell application object'
select @objshellapplication=0
exec @hr = sp_oacreate 'shell.application', @objshellapplication out
if @hr!=0 goto dispose

--now we get the folder.
select  @objerrorobject = @objshellapplication,
       @strerrormessage = 'getting folder"' + @wildcard + '"',
       @command = 'namespace("'+@wildcard+'")'

select @objfolder=0
exec @hr = sp_oamethod @objshellapplication, @command, @objfolder out
if @objfolder is null
    begin
    exec sp_oadestroy @objshellapplication
    return --nothing there. sod the error message
    end

--and then the number of objects in the folder
select  @objerrorobject = @objfolder,
       @strerrormessage = 'getting count of folder items in "'+@wildcard+'"',
       @command = 'items.count'
exec @hr = sp_oamethod @objfolder, @command, @count out
--now get the folderitems collection
select  @objerrorobject = @objfolder,
        @strerrormessage = ' getting folderitems',
       @command='items()'
exec @hr = sp_oamethod @objfolder, @command, @objfolderitems output

select @i = 0, @rid = 0

--iterate through the folderitems collection
--http://msdn.microsoft.com/en-us/library/windows/desktop/bb787810(v=vs.85).aspx
while @hr=0 and @i<@count
    begin
    select @objerrorobject = @objfolderitems,
           @strerrormessage = ' getting folder item '+cast(@i as varchar(5)),
           @command='item(' + cast(@i as varchar(5))+')'
           --@command='getdetailsof('+ cast(@i as varchar(5))+',1)'
    exec @hr = sp_oamethod @objfolderitems, @command, @objitem output
    select  @objerrorobject = @objitem,
            @strerrormessage = ' getting folder item properties'
                   + cast(@i as varchar(5))

    exec @hr = sp_oamethod @objitem,'path', @name output
    if @hr!=0 break
    if @kp=0 select @name=stuff(@name,1,@lp,'')

    exec @hr = sp_oamethod @objitem,'type', @type output
    if @hr!=0 break

    exec @hr = sp_oamethod @objitem,'modifydate', @modifydate output
    if @hr!=0 break

    exec @hr = sp_oamethod @objitem,'size', @size output
    if @hr!=0 break
    /*
    exec @hr = sp_oamethod @objitem,'isfilesystem', @isfilesystem output
    if @hr!=0 break
    */
    exec @hr = sp_oamethod @objitem,'isfolder', @isfolder output
    if @hr!=0 break

    --and insert the properties into a table
    insert into @dir (rid, flags, [key], dt, n)
    select
        @rid,
        case @isFolder when 1 then 32 else 0 end,
        @name,
        @modifydate,
        @size

    exec sp_oadestroy @objitem
    select @objitem=0

    select @i=@i+1
    end -- files loop

dispose:

if @hr <> 0
    begin
    declare
        @source nvarchar(255),
        @description nvarchar(255),
        @helpfile nvarchar(255),
        @helpid int

    exec sp_oageterrorinfo @objerrorobject, @source output,
        @description output, @helpfile output, @helpid output
    select  @strerrormessage = 'error whilst '
            + coalesce(@strerrormessage, 'doing something') + ', '
            + coalesce(@description, '')
    -- insert into @dir(flags,[key]) select 16,left(@strerrormessage,2000)
    end

if @objitem!=0 exec sp_oadestroy @objitem
if @objfolder!=0 exec sp_oadestroy @objfolder
if @objshellapplication!=0 exec sp_oadestroy @objshellapplication

-- raiserror
if @hr!=0 select @i=cast(left(@strerrormessage,2000) as int)

-- ============================================================== sub folders ==
if @s=0 return

declare cs cursor local for
    select id,case @kp when 0 then @path+[key] else [key] end
    from @dir
    where rid=@rid and flags&32=32
open cs
while 1=1
    begin
    fetch next from cs into @rid,@name
    if @@fetch_status!=0 break

    insert into @dir (rid, flags, [key], dt, n)
    select @rid,flags,[key],dt,n
    from fn__dir(@name,@opt)

    end -- cursor cs
close cs
deallocate cs

return
end -- fn__dir