/*  leave this
    l:see LICENSE file
    g:utility
    v:090121\S.Zaglio: changed name from sp__execute_DTS
*/
CREATE PROC sp__run_dts
    @PkgName nvarchar(255),             -- Package Name (Defaults to most recent version)
    @param1 sysname=null,
    @value1 sysname=null,
    @Server nvarchar(255)=null,
    @ServerPWD nvarchar(255) = Null,        -- Server Password if using SQL Security to load Package (UID is SUSER_NAME())
    @IntSecurity bit = 0,            -- 0 = SQL Server Security, 1 = Integrated Security
    @PkgPWD nvarchar(255) = ''        -- Package Password
AS

/* examples:
    -- for running SQL server security authorization
    spExecuteDTS '127.0.0.1', 'dtsImportData', 'sa'
    --/ or /--
    spExecuteDTS '127.0.0.1', 'dtsImportData', 'sa', 0

    -- for running SQL server security authorization
    spExecuteDTS '127.0.0.1', 'dtsImportData', 'sa', 1
*/

SET NOCOUNT ON
/*
    Return Values
    - 0 Successfull execution of Package
    - 1 OLE Error
    - 9 Failure of Package
*/

if @Server is null set @Server=@@servername

DECLARE @hr int, @ret int, @oPKG int, @Cmd nvarchar(1000)

-- Create a Pkg Object
EXEC @hr = sp_OACreate 'DTS.Package', @oPKG OUTPUT
IF @hr <> 0
BEGIN
    PRINT '***  Create Package object failed'
    EXEC sp__displayoaerrorinfo @oPKG, @hr
    RETURN 1
END

-- Evaluate Security and Build LoadFromSQLServer Statement
IF @IntSecurity = 0
    SET @Cmd = 'LoadFromSQLServer("' + @Server +'", "' + SUSER_SNAME() + '", "' + @ServerPWD + '", 0, "' + @PkgPWD + '", , , "' + @PkgName + '")'
ELSE
    SET @Cmd = 'LoadFromSQLServer("' + @Server +'", "", "", 256, "' + @PkgPWD + '", , , "' + @PkgName + '")'

EXEC @hr = sp_OAMethod @oPKG, @Cmd, NULL

IF @hr <> 0
BEGIN
        PRINT '***  LoadFromSQLServer failed'
        EXEC sp__displayoaerrorinfo @oPKG , @hr
        RETURN 1
END

-- set parameters
if not @param1 is null begin
    EXEC @hr = sp_OAMethod @oPKG, 'AddGlobalVariable', @Name = @param1, @Value = @value1
    IF @hr <> 0 PRINT 'Cant Add Global Var'
end




-- Execute Pkg
EXEC @hr = sp_OAMethod @oPKG, 'Execute'
IF @hr <> 0
BEGIN
        PRINT '***  Execute failed'
        EXEC sp__displayoaerrorinfo @oPKG , @hr
        RETURN 1
END

-- Check Pkg Errors
EXEC @ret=sp__DisplayPkgErrors @oPKG

-- Unitialize the Pkg
EXEC @hr = sp_OAMethod @oPKG, 'UnInitialize'
IF @hr <> 0
BEGIN
        PRINT '***  UnInitialize failed'
        EXEC sp__displayoaerrorinfo @oPKG , @hr
        RETURN 1
END

-- Clean Up
EXEC @hr = sp_OADestroy @oPKG
IF @hr <> 0
BEGIN
    EXEC sp__displayoaerrorinfo @oPKG , @hr
    RETURN 1
END

RETURN @ret