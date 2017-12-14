/*  leave this
    l:see LICENSE file
    g:utility
    v:130614\s.zaglio: added _ to non word and sentence
    v:130612\s.zaglio: added bounds,non_word,non_sentence
    v:120517\s.zaglio: removed from core group
    v:120201\s.zaglio: added to core group
    v:111222\s.zaglio: added gcs,gce,lcc
    v:111111\s.zaglio: added space
    v:100404\s.zaglio: added return values
    v:100328\s.zaglio: changed to table function and expanded to more symbols replace old fn__crlf,fn__seps
    v:091027\s.zaglio: for simplicity
    t:
        sp__find 'fn__crlf' sp__find 'fn__seps'
        sp__find 'char(13)' sp__find 'char(10)' sp__find 'char(9)'
    todo: replace all char(13),char(10),char(9)
*/
CREATE function [dbo].[fn__sym]()
returns table
as
return
    select
        -- classic txt symbols
        char(ascii(' ')) [space],
        char(13) cr,char(10) lf,char(13)+char(10) crlf,char(9) tab,
        -- path separators
        '\' psep, '/' usep,
        -- returns values
        0 ok, -1 help,
        -- group comment start and end
        '/*' gcs, '*/' gce,
        -- line code commend
        '--' lcc,
        -- bounds of a (t)sql word
        's''"_*+/,.;:\<>()=¬'+char(13)+char(10)+' '+char(9) bounds,
        '%[^a-z0-9_]%' non_word,
        '%[^a-z0-9 _]%' non_sentence
-- end fn__sym