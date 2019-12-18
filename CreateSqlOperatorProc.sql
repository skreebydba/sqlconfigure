-- Create a new stored procedure called 'CreateNewOperator' in schema 'dbo'
-- Drop the stored procedure if it already exists
IF EXISTS (
SELECT *
    FROM INFORMATION_SCHEMA.ROUTINES
WHERE SPECIFIC_SCHEMA = N'dbo'
    AND SPECIFIC_NAME = N'CreateNewOperator'
    AND ROUTINE_TYPE = N'PROCEDURE'
)
DROP PROCEDURE dbo.CreateNewOperator
GO
-- Create the stored procedure in the specified schema
CREATE PROCEDURE dbo.CreateNewOperator
    @operatorname SYSNAME,
    @operatoremail NVARCHAR(500) 
-- add more stored procedure parameters here
AS
    -- body of the stored procedure
    EXEC msdb.dbo.sp_add_operator @name=@operatorname, 
		@enabled=1, 
		@pager_days=0, 
		@email_address=@operatoremail
GO
-- example to execute the stored procedure we just created
EXECUTE dbo.CreateNewOperator @operatorname = N'SqlOperator', @operatoremail = 'fgill@concurrency.com';
GO