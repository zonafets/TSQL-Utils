/*  leave this for other app
    l:see LICENSE file
    g:obj,utility
    v:131006\s.zaglio: updated
    v:120517\s.zaglio: generic types
*/
CREATE view [tids] as
select
    0 as free,      -- the record can be replaced or id reused
    1 as cnt,       -- counter
    2 as tid ,      -- type id masker
    3 as flg ,      -- flags definition
    4 as seq ,      -- sequence type
    5 as mem ,      -- memory
    6 as obj ,      -- generic object
    7 as usr ,      -- user name
    8 as host,      -- host name
    9 as srv ,      -- server (131006\s.zaglio: modified from svr)
    10 as app ,     -- application
    11 as ev  ,     -- event
    12 as code,     -- code/programming/line of text
    13 as tsk ,     -- task, job, activity, actions, etc.
    14 as range,    -- range values
    15 as grp ,     -- used for groups, lists, etc.
    16 as db  ,     -- database
    17 as email,    -- email record
    18 as html,     -- html record
    19 as body,     -- body of email or html
    20 as iospc,    -- i/o specific
    21 as ioseg,    -- i/o specific segment
    22 as url,      -- unified resource locator
    23 as [file],   -- file name
    24 as [dir],    -- dir for file (parent); the path is the url
    25 as [prop],   -- property
    -1 as [tid.last]-- (131006\s.zaglio: modified from tids.last)