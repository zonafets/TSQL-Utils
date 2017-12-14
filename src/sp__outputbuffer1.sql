/*  leave this
    l:see LICENSE file
    g:utility
    v:080923\S.Zaglio: used to get complete error description of @@error
    t:begin declare @s nvarchar(2000) exec('truncate table_test') exec sp__outputbuffer @s out print @s end
*/
CREATE PROCEDURE sp__outputbuffer1 @errmsg nvarchar(500) OUTPUT AS
    DECLARE @dbccrow nchar(77),
            @msglen  int,
            @lenstr  nchar(2),
            @sql     nvarchar(2000),
            @s       tinyint

    -- Catch the output buffer.
    CREATE TABLE #DBCCOUT (col1 nchar(77) NOT NULL)
    INSERT INTO #DBCCOUT
         EXEC ('DBCC OUTPUTBUFFER(@@spid)')

    -- Set up a cursor over the table. We skip the first
    -- row, because there is nothing of interest.
    DECLARE error_cursor CURSOR STATIC FORWARD_ONLY FOR
        SELECT col1
        FROM   #DBCCOUT
        WHERE  left(col1, 8) <> replicate('0', 8)
        ORDER  BY col1

    -- Init variable, and open cursor.
    SELECT @errmsg  = ''
    OPEN error_cursor
    FETCH NEXT FROM error_cursor INTO @dbccrow

    -- On this first row we find the length.
    SELECT @lenstr = substring(@dbccrow, 15, 2)

    -- Convert hexstring to int
    SELECT @sql = 'SELECT @int = convert(int, 0x00' + @lenstr + ')'
    EXEC sp_executesql @sql, N'@int int OUTPUT', @msglen OUTPUT

    -- @s is where the ntext part of the buffer starts.
    SELECT @s = 62

    -- Now assemble rest of string.
    WHILE @@FETCH_STATUS = 0 AND datalength(@errmsg) - 1 < 2 * @msglen
    BEGIN
      SELECT @errmsg = @errmsg + substring(@dbccrow, @s + 1, 1) +
                                 substring(@dbccrow, @s + 3, 1) +
                                 substring(@dbccrow, @s + 5, 1) +
                                 substring(@dbccrow, @s + 7, 1) +
                                 substring(@dbccrow, @s + 9, 1) +
                                 substring(@dbccrow, @s + 11, 1) +
                                 substring(@dbccrow, @s + 13, 1) +
                                 substring(@dbccrow, @s + 15, 1)
      FETCH NEXT FROM error_cursor INTO @dbccrow
    END

    CLOSE error_cursor
    DEALLOCATE error_cursor

    -- Now chop first character which is the length, and cut after end.
    SELECT @errmsg = substring(@errmsg, 2, @msglen)