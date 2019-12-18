-- Create a new stored procedure called 'SetSqlServerMaxMemory' in schema 'dbo'
-- Drop the stored procedure if it already exists
IF EXISTS (
SELECT *
    FROM INFORMATION_SCHEMA.ROUTINES
WHERE SPECIFIC_SCHEMA = N'dbo'
    AND SPECIFIC_NAME = N'SetSqlServerMaxMemory'
    AND ROUTINE_TYPE = N'PROCEDURE'
)
DROP PROCEDURE dbo.SetSqlServerMaxMemory
GO
-- Create the stored procedure in the specified schema
CREATE PROCEDURE dbo.SetSqlServerMaxMemory
    @noexec  BIT = 1
AS
    -- body of the stored procedure
    SET NOCOUNT ON;

    DECLARE @mem NVARCHAR(10)
    DECLARE @memOut NVARCHAR(10)
    DECLARE @totalOSReserve INT
    DECLARE @4_16 INT
    DECLARE @8Above16 INT
    DECLARE @serverVersion INT
    DECLARE @valueinuse INT
    DECLARE @sql NVARCHAR(MAX)
    DECLARE @paramdefs NVARCHAR(500)
    /* Put this into a parameter so it's configurable */
    DECLARE @osMem INT;

    /* Done this way to handle older versions of SQL Server */
    SET @osMem = 1 -- leave 1GB for the OS
    SET @8Above16 = 0 -- leave it 0 by default if you don't have more than 8GB of memory
    SET @serverVersion = LEFT(CAST(SERVERPROPERTY('productversion') AS VARCHAR(100)),CHARINDEX('.',CAST(SERVERPROPERTY('productversion') AS VARCHAR(100)),1)-1)
    SET @paramdefs = N'@memOut INT OUTPUT'

    /* Setup the dynamic SQL
    We need the physical memory values in GB since that's the scale we are working with. */
    IF @serverVersion > 10
        SET @sql = '(SELECT @memOut = (physical_memory_KB/1024/1024) FROM sys.dm_os_sys_info)'
    ELSE
        SET @sql = '(select @memOut = (physical_memory_in_bytes/1024/1024/1024) FROM sys.dm_os_sys_info)'

    /* Get the amount of physical memory on the box */
    EXEC sp_executesql @sql, @paramdefs, @memOut = @mem OUTPUT

    /* Start the Math */
    IF @mem > 16
        BEGIN
            SET @4_16 = 4
            SET @8Above16 = (@mem-16)/8
        END
    ELSE
        BEGIN
            SET @4_16 = @mem/4
        END

    /* Total amount of memory reserved for the OS */
    SELECT @totalOSReserve = @osMem + @4_16 + @8Above16
    SELECT @mem = (@mem-@totalOSReserve)*1024

    SELECT @valueinuse = CAST(value_in_use AS INT)
    FROM sys.configurations
    WHERE name = 'max server memory (MB)';

    /* Use sys.configurations to find the current value */
    SELECT (@mem/1024)+@totalOSReserve AS 'Total Physical Memory'
        , @totalOSReserve AS 'Total OS Reserve'
        , @mem AS 'Expected SQL Server Memory'
        , @valueinuse AS 'Current Configured Value'


    /* If max server memory (mb) is not equal to the recommended value 
    generate statements to update it

    If @noexec is set to 1, print the statements
    Otherwise execute them */

    IF @mem <> @valueinuse
    BEGIN

        IF @noexec = 1
        BEGIN
        
            PRINT 'EXEC sp_configure ''show advanced options'', 1 ;
    RECONFIGURE;'
            PRINT 'EXEC sp_configure ''max server memory (MB)'', ' + @mem + ';
    RECONFIGURE;';
            PRINT 'EXEC sp_configure ''show advanced options'', 0 ;
    RECONFIGURE;'

        END
        ELSE
        BEGIN
            
            SELECT @sql = 'EXEC sp_configure ''show advanced options'', 1 ;RECONFIGURE;'
            EXEC sp_executesql @sql;
            SELECT @sql = CONCAT('EXEC sp_configure ''max server memory (MB)'', ', @mem, ';RECONFIGURE;'); 
            EXEC sp_executesql @sql;
            SELECT @sql = 'EXEC sp_configure ''show advanced options'', 0 ;RECONFIGURE;'
            EXEC sp_executesql @sql;
            
        END

    END
    ELSE
    BEGIN

        PRINT 'max server memory (mb) is set according to best practices';

    END
GO
