/*  leave this
    l:see LICENSE file
    g:utility
    v:081207\S.Zaglio: get foreing keys hierarchy
    c:originally from http://www.sqlservercentral.com/scripts/Maintenance+and+Management/30445/
*/
create proc sp__tree_fk
as
begin
/******************************************************************************
This script will run through the foreign keys on tables to produce a hierarchy
of the tables in a database.

The heirarchy produced will be :
0    Tables that have no FK relationships at all, as either as 'parents' or
    'children'
1    Tables which are at the top of the tree, and have no 'parents', only
    'children'
2    ...you can figure it out from here...



If you need to repopulate the database your table order would be 0,1,2...

To delete from tables you need to start at the highest number  ...3,2,1,0


*******************************************************************************/


SET NOCOUNT ON

DECLARE
    @intCounter    INT,
    @intRowCount    INT


CREATE TABLE #Hierarchy
    (Hierarchy    INT,
    Child        VARCHAR(100),
    Parent         VARCHAR(100))

-- Set the variables
SELECT @intCounter = 1
SELECT @intRowCount = 1


-- Populate the table
INSERT INTO #Hierarchy
SELECT DISTINCT 1 AS 'Hierarchy', S1.name AS 'Child', SO.Name AS 'Parent'
FROM dbo.sysforeignkeys FK
INNER JOIN dbo.sysobjects SO
ON FK.rkeyID = SO.id
INNER JOIN dbo.sysobjects S1
ON FK.fkeyID = S1.id



WHILE @intRowCount <> 0
BEGIN
    UPDATE #Hierarchy
    SET Hierarchy = Hierarchy + 1
    WHERE Hierarchy = @intCounter
    AND Parent IN  (SELECT DISTINCT Child
            FROM #Hierarchy
            WHERE Hierarchy = @intCounter)


    SET @intRowCount = @@Rowcount

    SELECT @intCounter = @intCounter + 1
END


-- Add the tables that have no Foriegn Key relationships...
INSERT INTO #Hierarchy
SELECT -1, [name], ' - '
FROM dbo.sysobjects
WHERE [name] NOT IN (SELECT DISTINCT Parent FROM #Hierarchy)
AND [Name] NOT IN (SELECT DISTINCT Child FROM #Hierarchy)
AND xtype = 'U'


-- Add the tables that are Parents only
INSERT INTO #Hierarchy
SELECT DISTINCT 0, Parent, ' - '
From #Hierarchy
WHERE Parent NOT IN (SELECT Child FROM #Hierarchy)
AND Hierarchy <> -1

-- Add 1 to adjust the hierarchies to start at 0
UPDATE #Hierarchy
SET Hierarchy = Hierarchy + 1


-- Display the results
SELECT DISTINCT Hierarchy, Child, Parent
FROM #Hierarchy
ORDER BY Hierarchy, Child, Parent

-- Clean up
DROP TABLE #Hierarchy
end -- proc