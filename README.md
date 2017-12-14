# TSQL-Utils
This is a collection of stored procedures and functions made from ground or found around the world and adapted or rewritten under common style.

The file **utility.sql** contain a single script that installs all the SPs/FNs (objects).
After the installation the same script can be generated with query command:

`sp__script_group "utility"`

The file **utility.cvs** contains the list of objects with info about last version and comment.
The folder **src** contains the single objects. 
This last two can be generated with query command:

`sp__script_group_tofile "utility",@path`

Each utility has its help. To see it call the SP without parameters.
Global constants are stored into Views (see tids.sql for example).

Every object starts with a structured comment made with tags:

```sql
/*
g:group1, group2, group3
r:YYMMDD\f.lname: R tag means release (cannot be deployed)
v:YYMMDD\f.lname: V tag means version
...
*/
```

This structure is used by script functions to such as `fn__script_group` to allow the creation of high level utilities to manage code and interact with developer as shown in this [video](https://youtu.be/MBP_jCdrCDc).

 