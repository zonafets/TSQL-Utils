/*  leave this
    l:see LICENSE file
    g:utility
    v:100919\s.zaglio: parse registry name and split into parts
    t:select * from fn__reg_parse('hklm\key1\key2\val')
*/
create function fn__reg_parse(@key nvarchar(512))
returns table
as
return
select
    case left(@key,charindex('\',@key)-1)
    when 'hklm' then 'hkey_local_machine'
    when 'hkcu' then 'hkey_current_user'
    else left(@key,charindex('\',@key)-1)
    end as [root],

    substring(@key,charindex('\',@key)+1,
              dbo.fn__charindex('\',@key,-1)
              -charindex('\',@key)-1)
    as [key],

    substring(@key,dbo.fn__charindex('\',@key,-1)+1,128)
    as [value]
-- end fn__reg_parse