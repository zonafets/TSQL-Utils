/*  leave this
    l:see LICENSE file
    g:utility
    v:100212\s.zaglio: return file info
    c:from http://www.sqlteam.com/forums/topic.asp?TOPIC_ID=99653
    t:select * from fn__file_property('c:\boot.ini')
*/
create function fn__file_property(
    @filename nvarchar (1024)
)
returns @results table (
    errorcode tinyint default (0),
    propname nvarchar (255),
    propvalue sql_variant)
as
begin
declare @oleresult int
declare @fs int
declare @fileid int
declare @message nvarchar (4000)
declare @errorsource nvarchar (255)
declare @errordesc nvarchar (255)
declare @int int
declare @nvarchar nvarchar (1024)
declare @datetime datetime
declare @bigint bigint

-- create an instance of the file system object
execute @oleresult = sp_oacreate 'scripting.filesystemobject', @fs out
if @oleresult <> 0
begin
exec sp_oageterrorinfo @fs, @errorsource out, @errordesc out

insert @results (errorcode, propname, propvalue)
values (1, @errorsource, @errordesc)

return
end

exec @oleresult = sp_oamethod @fs, 'getfile', @fileid out, @filename
if @oleresult <> 0
begin
exec sp_oageterrorinfo @fs, @errorsource out, @errordesc out

insert @results (errorcode, propname, propvalue)
values (1, @errorsource, @errordesc)

return
end

exec @oleresult = sp_oagetproperty @fileid, 'attributes', @int out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'attributes', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('attributes', @int)

exec @oleresult = sp_oagetproperty @fileid, 'datecreated', @datetime out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'datecreated', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('datecreated', @datetime)

exec @oleresult = sp_oagetproperty @fileid, 'datelastaccessed', @datetime out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'datelastaccessed', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('datelastaccessed', @datetime)

exec @oleresult = sp_oagetproperty @fileid, 'datelastmodified', @datetime out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'datelastmodified', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('datelastmodified', @datetime)

exec @oleresult = sp_oagetproperty @fileid, 'name', @nvarchar out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'name', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('name', @nvarchar)

exec @oleresult = sp_oagetproperty @fileid, 'path', @nvarchar out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'path', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('path', @nvarchar)

exec @oleresult = sp_oagetproperty @fileid, 'shortpath', @nvarchar out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'shortpath', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('shortpath', @nvarchar)

exec @oleresult = sp_oagetproperty @fileid, 'size', @bigint out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'size', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('size', @bigint)

exec @oleresult = sp_oagetproperty @fileid, 'type', @nvarchar out
if @oleresult <> 0
begin
insert @results (errorcode, propname, propvalue)
values (1, 'type', '<error retrieving property>')
end
else
insert @results (propname, propvalue)
values ('type', @nvarchar)

execute @oleresult = sp_oadestroy @fileid
execute @oleresult = sp_oadestroy @fs

return
end -- function