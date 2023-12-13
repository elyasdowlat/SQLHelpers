-- =============================================
-- Author: Morteza Tavakoli	And Elyas Dowlatabadi						
-- Date: 2023-12-13														
-- ShamsiDate: 1402-09-22												
-- Description:	Replace all @Oldvalue Guids with @NewValue in all table and column of database
-- Persian Description: جایگزینی یک GUIDبا یک مقدار جدید 
-- EXP: EXEC SP_Generate_Replace_Guid_Script @Oldvalue='00000000-0000-0000-0000-000000000000',@NewValue='11111111-1111-1111-1111-111111111111'
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF object_id('Sp_GenerateReplaceGuidScript') IS NULL
    EXEC ('CREATE PROCEDURE [dbo].[Sp_GenerateReplaceGuidScript] AS SELECT 1')
GO

ALTER PROCEDURE Sp_GenerateReplaceGuidScript 
	-- Add the parameters for the stored procedure here
	@OldValue UniqueIdentifier,
	@NewValue UniqueIdentifier
AS
BEGIN
	DECLARE @Row int=1;
	DECLARE @RowCount int;
	DECLARE @SchemaName nvarchar(250);
	DECLARE @TableName nvarchar(250);
	DECLARE @ColumnName nvarchar(250);
	DECLARE @Query nvarchar(1000);
	DECLARE @IsExistsQuery NVARCHAR(MAX);
	DECLARE @IsExists BIT=0;
	
	-- drop temp table if found
	IF EXISTS(SELECT * FROM sys.tables	WHERE name = (N'#TempAllGUIDColumn') ) 
		DROP TABLE #TempAllGUIDColumn

	-- create temp table that hold all string type column in all tables of database 
	CREATE TABLE #TempAllGUIDColumn(id int identity(1, 1), schemaName nvarchar(250), tableName nvarchar(250), columnName nvarchar(250), typeName nvarchar(250),  colLength int)

	
	-- find all string type column and fill temp table
	INSERT INTO #TempAllGUIDColumn(schemaName, tableName, columnName, typeName, colLength)
	SELECT 
		s.name schemaName, t.name tableName, c.name columnName, ty.name typeName, c.max_length colLength 
	FROM sys.columns c 
	JOIN sys.tables t ON t.object_id = c.object_id
	JOIN sys.schemas s on s.schema_id = t.schema_id
	JOIN sys.types ty on c.system_type_id = ty.system_type_id
	WHERE ty.name ='UniqueIdentifier'
	ORDER BY s.name, t.name, c.name
	
	SELECT @RowCount = count(*) FROM #TempAllGUIDColumn
	-- loop in all column and update 
	WHILE @Row <= @RowCount 
	BEGIN
		SELECT @SchemaName = schemaName, @TableName = tableName, @ColumnName = columnName FROM #TempAllGUIDColumn WHERE id = @Row
		SET @IsExistsQuery=N'(select @IsExists=count(*) from ['+@SchemaName+'].['+@TableName+'] WHERE ' + @SchemaName + '.' + @TableName + '.[' + @ColumnName + ']='''+ convert(nvarchar(36),@OldValue)  +''')'
		EXEC sp_executesql @IsExistsQuery,N'@IsExists BIT output',@IsExists output;
		IF (@IsExists>0)
		BEGIN
			SET @Query = ' UPDATE ' + @SchemaName + '.' + @TableName +
						 ' SET [' + @ColumnName + '] = ''' + convert(nvarchar(36), @NewValue) +''''+
						 ' WHERE ' + @SchemaName + '.' + @TableName + '.[' + @ColumnName + ']='''+ convert(nvarchar(36),@OldValue)  +''''
			PRINT @Query
		END
		SET @Row = @Row + 1
	END
	
	DROP TABLE #TempAllGUIDColumn
END

