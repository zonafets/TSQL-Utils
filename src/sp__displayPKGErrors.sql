/*  leave this
    l:see LICENSE file
    g:utility
    v:091018\s.zaglio: display errors from spExecuteDTS execution
*/
CREATE PROC sp__displayPKGErrors
    @oPkg As integer
AS

SET NOCOUNT ON

DECLARE @StepCount int
DECLARE @Steps int
DECLARE @Step int
DECLARE @StepResult int
DECLARE @oPkgResult int
DECLARE @hr int

DECLARE @StepName nvarchar(255)
DECLARE @StepDescription nvarchar(255)

IF OBJECT_ID('tempdb..#PkgResult') IS NOT NULL
        DROP TABLE #PkgResult

CREATE TABLE #PkgResult
(
    StepName nvarchar(255) NOT NULL,
    StepDescription nvarchar(255) NOT NULL,
    Result bit NOT NULL
)

SELECT @oPkgResult = 0

EXEC @hr = sp_OAGetProperty @oPkg, 'Steps', @Steps OUTPUT
IF @hr <> 0
BEGIN
        PRINT '***  Unable to get steps'
        EXEC sp__displayoaerrorinfo @oPkg , @hr
        RETURN 1
END

EXEC @hr = sp_OAGetProperty @Steps, 'Count', @StepCount OUTPUT
IF @hr <> 0
BEGIN
        PRINT '***  Unable to get number of steps'
        EXEC sp__displayoaerrorinfo @Steps , @hr
        RETURN 1
END

WHILE @StepCount > 0
BEGIN
    EXEC @hr = sp_OAGetProperty @Steps, 'Item', @Step OUTPUT, @StepCount
    IF @hr <> 0
    BEGIN
            PRINT '***  Unable to get step'
            EXEC sp__displayoaerrorinfo @Steps , @hr
            RETURN 1
    END

    EXEC @hr = sp_OAGetProperty @Step, 'ExecutionResult', @StepResult OUTPUT
    IF @hr <> 0
    BEGIN
            PRINT '***  Unable to get ExecutionResult'
            EXEC sp__displayoaerrorinfo @Step , @hr
            RETURN 1
    END


    EXEC @hr = sp_OAGetProperty @Step, 'Name', @StepName OUTPUT
    IF @hr <> 0
    BEGIN
            PRINT '***  Unable to get step Name'
            EXEC sp__displayoaerrorinfo @Step , @hr
            RETURN 1
    END

    EXEC @hr = sp_OAGetProperty @Step, 'Description', @StepDescription OUTPUT
    IF @hr <> 0
    BEGIN
            PRINT '***  Unable to get step Description'
            EXEC sp__displayoaerrorinfo @Step , @hr
            RETURN 1
    END

    INSERT #PkgResult VALUES(@StepName, @StepDescription, @StepResult)
    PRINT 'Step ' + @StepName + ' (' + @StepDescription + ') ' + CASE WHEN @StepResult = 0 THEN 'Succeeded' ELSE 'Failed' END

    SELECT @StepCount = @StepCount - 1
    SELECT @oPkgResult = @oPkgResult + @StepResult
END

SELECT * FROM #PkgResult

IF @oPkgResult > 0
BEGIN
    PRINT 'Package had ' + CAST(@oPkgResult as nvarchar) + ' failed step(s)'
    RETURN 9
END
ELSE
BEGIN
    PRINT 'Packge Succeeded'
    RETURN 0
END