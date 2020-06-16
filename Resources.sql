
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  Get table Info
-------------------------------------------------------------------------------------------------------------------------------------------------------------------


SELECT 
    c.name 'Column Name',
    t.Name 'Data type',
    c.max_length 'Max Length',
    c.precision ,
    c.scale ,
    c.is_nullable,
    ISNULL(i.is_primary_key, 0) 'Primary Key'
FROM    
    sys.columns c
INNER JOIN 
    sys.types t ON c.user_type_id = t.user_type_id
LEFT OUTER JOIN 
    sys.index_columns ic ON ic.object_id = c.object_id AND ic.column_id = c.column_id
LEFT OUTER JOIN 
    sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
WHERE
    c.object_id = OBJECT_ID('')
order by c.name



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- For info of a tempdb table
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


SELECT [column] = c.name, 
       [type] = t.name, c.max_length, c.precision, c.scale, c.is_nullable 
    FROM tempdb.sys.columns AS c
    INNER JOIN tempdb.sys.types AS t
    ON c.system_type_id = t.system_type_id
    AND t.system_type_id = t.user_type_id
    WHERE [object_id] = OBJECT_ID(N'tempdb.dbo.');


-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--    Get Partition Info
-------------------------------------------------------------------------------------------------------------------------------------------------------------------


select max(rows), object_id from sys.partitions group by object_id order by object_id


-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--    FOR SSISDB
-------------------------------------------------------------------------------------------------------------------------------------------------------------------


Use SSISDB
SELECT fld.Name as FolderName

,fld.created_By_Name as folderCreatdBy

,fld.Created_time as folderCreateddate 
,proj.name projectName
,proj.created_time
,proj.last_deployed_time
,proj.deployed_by_name
,proj.folder_id
,pkg.[project_version_lsn]
,pkg.[name] as Pakagename
,pkg.[description]
,pkg.[package_format_version]
,pkg.[version_major]
,pkg.[version_minor]
,pkg.[version_build]
,pkg.[version_comments]
FROM [SSISDB].[internal].folders fld
left outer join [SSISDB].[internal].[projects] proj on proj.folder_id=fld.folder_id
left outer join [SSISDB].[internal].[packages] pkg on pkg.project_id=pkg.project_id
where pkg.name = '.dtsx'  and proj.name = '' --and fld.folder_id = 10014
Order by last_deployed_time DESC


-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--    Row Groups for CSI
-------------------------------------------------------------------------------------------------------------------------------------------------------------------

 select top 10 * from sys.column_store_row_groups

 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--   List all indexes
-------------------------------------------------------------------------------------------------------------------------------------------------------------------

select schema_name(t.schema_id) AS [Schema_Name], t.[name] as table_view, 
    case when t.[type] = 'U' then 'Table'
        when t.[type] = 'V' then 'View'
        end as [object_type],
    i.index_id,
    case when i.is_primary_key = 1 then 'Primary key'
        when i.is_unique = 1 then 'Unique'
        else 'Not unique' end as [type],
    i.[name] as index_name,
	t.create_date as CreationDate ,
	t.modify_date as LastModifiedDate,
    substring(column_names, 1, len(column_names)-1) as [columns],
    case when i.[type] = 1 then 'Clustered index'
        when i.[type] = 2 then 'Nonclustered unique index'
        when i.[type] = 3 then 'XML index'
        when i.[type] = 4 then 'Spatial index'
        when i.[type] = 5 then 'Clustered columnstore index'
        when i.[type] = 6 then 'Nonclustered columnstore index'
        when i.[type] = 7 then 'Nonclustered hash index'
        end as index_type
from sys.objects t
    inner join sys.indexes i
        on t.object_id = i.object_id
    cross apply (select col.[name] + ', '
                    from sys.index_columns ic
                        inner join sys.columns col
                            on ic.object_id = col.object_id
                            and ic.column_id = col.column_id
                    where ic.object_id = t.object_id
                        and ic.index_id = i.index_id
                            order by col.column_id
                            for xml path ('') ) D (column_names)
where t.is_ms_shipped <> 1
and index_id > 0
order by schema_name(t.schema_id) + '.' + t.[name], i.index_id

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--   Show Statistics
-------------------------------------------------------------------------------------------------------------------------------------------------------------------


dbcc show_statistics ('','') -- <Table Name>	 , <Index Name>
					


-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  Index Usage Stats
-------------------------------------------------------------------------------------------------------------------------------------------------------------------



select top 10 * from sys.dm_db_index_usage_stats


-------------------------------------------------------------------------------------------------------------------------------------------------------------------
--  Details About Statistics
-------------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT DISTINCT

OBJECT_NAME(s.[object_id]) AS TableName,
c.name AS ColumnName,
s.name AS StatName,
s.auto_created,
s.user_created,
s.no_recompute,
s.[object_id],
s.stats_id,
sc.stats_column_id,
sc.column_id,
STATS_DATE(s.[object_id], s.stats_id) AS LastUpdated
FROM sys.stats s JOIN sys.stats_columns sc 
              ON sc.[object_id] = s.[object_id] AND sc.stats_id = s.stats_id
JOIN sys.columns c ON c.[object_id] = sc.[object_id] AND c.column_id = sc.column_id
JOIN sys.partitions par ON par.[object_id] = s.[object_id]
JOIN sys.objects obj ON par.[object_id] = obj.[object_id]
WHERE OBJECTPROPERTY(s.OBJECT_ID,'IsUserTable') = 1 --and obj.name like 'ServiceComponentOfferingDefinition'
AND (s.auto_created = 1 OR s.user_created = 1) --and c.name = 'billableId'
--AND OBJECT_NAME(s.[object_id])
--IN ()
order by lastUpdated DESC

-------------------------------------------------------------------------------------------------------------
--Check System Generated Stats
-------------------------------------------------------------------------------------------------------------

SELECT stat.name AS 'Statistics',
 OBJECT_NAME(stat.object_id) AS 'Object',
 COL_NAME(scol.object_id, scol.column_id) AS 'Column'
into #QA07_Stats
FROM sys.stats AS stat (NOLOCK) Join sys.stats_columns AS scol (NOLOCK)
 ON stat.stats_id = scol.stats_id AND stat.object_id = scol.object_id
 INNER JOIN sys.tables AS tab (NOLOCK) on tab.object_id = stat.object_id
--WHERE stat.name like '_WA%' 
ORDER BY stat.name



SELECT OBJECT_NAME(object_id) AS [ObjectName]
      ,[name] AS [StatisticName]
      ,STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
FROM sys.stats
where OBJECT_NAME(Object_Id) =''
order by StatisticUpdateDate desc
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-- Create table of sessions to find and kill yours
-------------------------------------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID ('tempdb..#sp_who2') is not null
DROP table #sp_who2

CREATE TABLE #sp_who2
    (
      SPID INT,
      Status VARCHAR(1000) NULL,
      Login SYSNAME NULL,
      HostName SYSNAME NULL,
      BlkBy SYSNAME NULL,
      DBName SYSNAME NULL,
      Command VARCHAR(1000) NULL,
      CPUTime INT NULL,
      DiskIO BIGINT NULL, -- int
      LastBatch VARCHAR(1000) NULL,
      ProgramName VARCHAR(1000) NULL,
      SPID2 INT
      , rEQUESTID INT NULL --comment out for SQL 2000 databases

    )


INSERT  INTO #sp_who2
EXEC sp_who2

SELECT  *
FROM    #sp_who2
WHERE   login like '%%'-- User



-- How to kill multiple sessions
SELECT 'KILL ' + CAST(session_id as varchar(100)) AS Sessions_to_kill
FROM sys.dm_exec_requests where session_id in (58,286,288,305,414,426)
GO

-------------------------------------------------------------------------------------------------------------------------------------------------
-- Find out metadata of resultset of a Stored procedure
-------------------------------------------------------------------------------------------------------------------------------------------------


select * from sys.dm_exec_describe_first_result_set_for_object 
    ( OBJECT_ID('TableName') , 1) order by name

-------------------------------------------------------------------------------------------------------------------------------------------------
--For info of segments on Columnstore Index
-------------------------------------------------------------------------------------------------------------------------------------------------

select
OBJECT_NAME(p.object_id) as tableName
,cs.segment_id
,cs.min_data_id
,cs.max_data_id
,cs.row_count
,cs.on_disk_size

from sys.column_store_segments as cs
inner join sys.partitions as p on cs.hobt_id = p.hobt_id

where p.object_id = object_id('dbo.TableName') and cs.column_id = 1
order by 
cs.segment_id ASC


-------------------------------------------------------------------------------------------------------------------------------------------------
-- TempDb:  space usage by session including the current requests
-------------------------------------------------------------------------------------------------------------------------------------------------

SELECT  COALESCE(T1.session_id, T2.session_id) [session_id] ,        T1.request_id ,
        COALESCE(T1.database_id, T2.database_id) [database_id],
        COALESCE(T1.[Total Allocation User Objects], 0)
        + T2.[Total Allocation User Objects] [Total Allocation User Objects] ,
        COALESCE(T1.[Net Allocation User Objects], 0)
        + T2.[Net Allocation User Objects] [Net Allocation User Objects] ,
        COALESCE(T1.[Total Allocation Internal Objects], 0)
        + T2.[Total Allocation Internal Objects] [Total Allocation Internal Objects] ,
        COALESCE(T1.[Net Allocation Internal Objects], 0)
        + T2.[Net Allocation Internal Objects] [Net Allocation Internal Objects] ,
        COALESCE(T1.[Total Allocation], 0) + T2.[Total Allocation] [Total Allocation] ,
        COALESCE(T1.[Net Allocation], 0) + T2.[Net Allocation] [Net Allocation] ,
        COALESCE(T1.[Query Text], T2.[Query Text]) [Query Text]
FROM    ( SELECT    TS.session_id ,
                    TS.request_id ,
                    TS.database_id ,
                    CAST(TS.user_objects_alloc_page_count / 128 AS DECIMAL(15,
                                                              2)) [Total Allocation User Objects] ,
                    CAST(( TS.user_objects_alloc_page_count
                           - TS.user_objects_dealloc_page_count ) / 128 AS DECIMAL(15,
                                                              2)) [Net Allocation User Objects] ,
                    CAST(TS.internal_objects_alloc_page_count / 128 AS DECIMAL(15,
                                                              2)) [Total Allocation Internal Objects] ,
                    CAST(( TS.internal_objects_alloc_page_count
                           - TS.internal_objects_dealloc_page_count ) / 128 AS DECIMAL(15,
                                                              2)) [Net Allocation Internal Objects] ,
                    CAST(( TS.user_objects_alloc_page_count
                           + internal_objects_alloc_page_count ) / 128 AS DECIMAL(15,
                                                              2)) [Total Allocation] ,
                    CAST(( TS.user_objects_alloc_page_count
                           + TS.internal_objects_alloc_page_count
                           - TS.internal_objects_dealloc_page_count
                           - TS.user_objects_dealloc_page_count ) / 128 AS DECIMAL(15,
                                                              2)) [Net Allocation] ,
                    T.text [Query Text]
          FROM      sys.dm_db_task_space_usage TS
                    INNER JOIN sys.dm_exec_requests ER ON ER.request_id = TS.request_id
                                                          AND ER.session_id = TS.session_id
                    OUTER APPLY sys.dm_exec_sql_text(ER.sql_handle) T
        ) T1
        RIGHT JOIN ( SELECT SS.session_id ,
                            SS.database_id ,
                            CAST(SS.user_objects_alloc_page_count / 128 AS DECIMAL(15,
                                                              2)) [Total Allocation User Objects] ,
                            CAST(( SS.user_objects_alloc_page_count
                                   - SS.user_objects_dealloc_page_count )
                            / 128 AS DECIMAL(15, 2)) [Net Allocation User Objects] ,
                            CAST(SS.internal_objects_alloc_page_count / 128 AS DECIMAL(15,
                                                              2)) [Total Allocation Internal Objects] ,
                            CAST(( SS.internal_objects_alloc_page_count
                                   - SS.internal_objects_dealloc_page_count )
                            / 128 AS DECIMAL(15, 2)) [Net Allocation Internal Objects] ,
                            CAST(( SS.user_objects_alloc_page_count
                                   + internal_objects_alloc_page_count ) / 128 AS DECIMAL(15,
                                                              2)) [Total Allocation] ,
                            CAST(( SS.user_objects_alloc_page_count
                                   + SS.internal_objects_alloc_page_count
                                   - SS.internal_objects_dealloc_page_count
                                   - SS.user_objects_dealloc_page_count )
                            / 128 AS DECIMAL(15, 2)) [Net Allocation] ,
                            T.text [Query Text]
                     FROM   sys.dm_db_session_space_usage SS
                            LEFT JOIN sys.dm_exec_connections CN ON CN.session_id = SS.session_id
                            OUTER APPLY sys.dm_exec_sql_text(CN.most_recent_sql_handle) T
                   ) T2 ON T1.session_id = T2.session_id

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- To get sp_who2 output in a table variable
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @Table TABLE(
        SPID INT,
        Status VARCHAR(MAX),
        LOGIN VARCHAR(MAX),
        HostName VARCHAR(MAX),
        BlkBy VARCHAR(MAX),
        DBName VARCHAR(MAX),
        Command VARCHAR(MAX),
        CPUTime INT,
        DiskIO INT,
        LastBatch VARCHAR(MAX),
        ProgramName VARCHAR(MAX),
        SPID_1 INT,
        REQUESTID INT
)

INSERT INTO @Table EXEC sp_who2

SELECT  *
FROM    @Table
WHERE DBName LIKE '%'


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- To check sessions and filter them on  condition
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


SELECT spid
,kpid
,login_time
,last_batch
,status
,hostname
,nt_username
,loginame
,hostprocess
,cpu
,memusage
,physical_io
FROM sys.sysprocesses
WHERE cmd = 'KILLED/ROLLBACK'

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- To check a session and how much percent complete
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT percent_complete,estimated_completion_time from sys.dm_exec_requests
where session_id=141


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- To update mail operators
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--SELECT * FROM msdb.dbo.sysoperators

--USE msdb ;  
--GO  
  
--EXEC dbo.sp_update_operator   
--    @name = N'Sherlock',  
--    @enabled = 1,  
--    @email_address = N'imakkav1@wm.com;pvyas@wm.com;zsadriwa@wm.com;smannepa@wm.com'
--GO  


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Add new sysoperator
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


--USE msdb ;  
--GO  

--EXEC select * from dbo.sp_add_operator  
--    @name = N'IT Elements',  
--    @enabled = 1,  
--    @email_address = N'IT-Elements@wm.com',  
--    --@pager_address = N'IT-Elements@wm.com',  
--    @weekday_pager_start_time = 90000,  
--    @weekday_pager_end_time = 180000,  
--    @pager_days = 0 ;  
--GO  


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- To find out tables in Schema
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

select schema_name(t.schema_id) as schema_name,
       t.name as table_name,
       t.create_date,
       t.modify_date
from sys.tables t
where schema_name(t.schema_id) = 'dbo' -- put schema name here
order by table_name;


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Get record counts of all tables in a database within all schemas 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

USE SherlockLanding
DECLARE @QueryString NVARCHAR(MAX) ;
SELECT @QueryString = COALESCE(@QueryString + ' UNION ALL ','')
                      + 'SELECT '
                      + '''' + QUOTENAME(SCHEMA_NAME(sOBJ.schema_id))
                      + '.' + QUOTENAME(sOBJ.name) + '''' + ' AS [TableName]
                      , COUNT(*) AS [RowCount] FROM '
                      + QUOTENAME(SCHEMA_NAME(sOBJ.schema_id))
                      + '.' + QUOTENAME(sOBJ.name) + ' WITH (NOLOCK) '
FROM sys.objects AS sOBJ
WHERE
      sOBJ.type = 'U'
      AND sOBJ.is_ms_shipped = 0x0
ORDER BY SCHEMA_NAME(sOBJ.schema_id), sOBJ.name ;
EXEC sp_executesql @QueryString
GO




------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Check projects and environment references
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT  reference_id, er.environment_name, p.name, p.project_id
  FROM  SSISDB.[catalog].environment_references er
        JOIN SSISDB.[catalog].projects p ON p.project_id = er.project_id



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Move TempDb to new location
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Check First where is it located.
USE TempDB
GO
EXEC sp_helpfile
GO

-- Use below and edit the new Location(FILENAME) in below snippet.

USE master
GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = tempdev, FILENAME = 'J:\SQL2016\Tempdb\Data\datatempdb.mdf')
GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = templog, FILENAME = 'J:\SQL2016\Tempdb\log\datatemplog.ldf')
GO

GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = temp2, FILENAME = 'J:\SQL2016\Tempdb\Data\tempdb_mssql_2.ndf')
GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = temp3, FILENAME = 'J:\SQL2016\Tempdb\Data\tempdb_mssql_3.ndf')
GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = temp4, FILENAME = 'J:\SQL2016\Tempdb\Data\tempdb_mssql_4.ndf')
GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = temp5, FILENAME = 'J:\SQL2016\Tempdb\Data\tempdb_mssql_5.ndf')
GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = temp6, FILENAME = 'J:\SQL2016\Tempdb\Data\tempdb_mssql_6.ndf')
GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = temp7, FILENAME = 'J:\SQL2016\Tempdb\Data\tempdb_mssql_7.ndf')
GO
ALTER DATABASE TempDB MODIFY FILE
(NAME = temp8, FILENAME = 'J:\SQL2016\Tempdb\Data\tempdb_mssql_8.ndf')
GO


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Check available space in TempDb
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

use tempdb

SELECT 
  name AS 'File Name' 
, physical_name AS 'Physical Name'
, size/128 AS 'Total Size in MB'
, size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS int)/128.0 AS 'Available Space In MB', * FROM sys.database_files



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Check Indexes on table
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


USE sherlock
SELECT
    sys.tables.name AS TBL_Name,
    sys.indexes.name AS IX_Name,
    sys.columns.name AS Column_Name
FROM sys.indexes
    INNER JOIN sys.tables ON sys.tables.object_id = sys.indexes.object_id
    INNER JOIN sys.index_columns ON sys.index_columns.index_id = sys.indexes.index_id
        AND sys.index_columns.object_id = sys.tables.object_id
    INNER JOIN sys.columns ON sys.columns.column_id = sys.index_columns.column_id
        AND sys.columns.object_id = sys.tables.object_id
WHERE sys.tables.name = 'TableName'
ORDER BY
    sys.tables.name,
    sys.indexes.name,
    sys.columns.name



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- check stats and dates on table
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT sp.stats_id, 
       name, 
       filter_definition, 
       last_updated, 
       rows, 
       rows_sampled, 
       steps, 
       unfiltered_rows, 
       modification_counter
FROM sys.stats AS stat
     CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = OBJECT_ID('dbo.TableName');


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- check role membership of users on server
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

;with ServerPermsAndRoles as
(
    select
        spr.name as principal_name,
        spr.type_desc as principal_type,
        spm.permission_name collate SQL_Latin1_General_CP1_CI_AS as security_entity,
        'permission' as security_type,
        spm.state_desc
    from sys.server_principals spr
    inner join sys.server_permissions spm
    on spr.principal_id = spm.grantee_principal_id
    where spr.type in ('s', 'u')

    union all

    select
        sp.name as principal_name,
        sp.type_desc as principal_type,
        spr.name as security_entity,
        'role membership' as security_type,
        null as state_desc
    from sys.server_principals sp
    inner join sys.server_role_members srm
    on sp.principal_id = srm.member_principal_id
    inner join sys.server_principals spr
    on srm.role_principal_id = spr.principal_id
    where sp.type in ('s', 'u')
)
select *
from ServerPermsAndRoles
WHERE security_type = 'role membership'
ORDER by principal_name 


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Check Backup sets
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


select   a.server_name, a.database_name,a.backup_start_date,a.backup_finish_date, a.backup_size,
CASE a.[type] -- Let's decode the three main types of backup here
 WHEN 'D' THEN 'Full'
 WHEN 'I' THEN 'Differential'
 WHEN 'L' THEN 'Transaction Log'
 ELSE a.[type]
END as BackupType
 ,b.physical_device_name
from msdb.dbo.backupset a join msdb.dbo.backupmediafamily b
  on a.media_set_id = b.media_set_id
where a.database_name Like 'DBName%'
order by a.database_name, a.backup_finish_date DESC



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- tempdb size and shrink
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
use tempdb
GO

DBCC FREEPROCCACHE -- clean cache
DBCC DROPCLEANBUFFERS -- clean buffers
DBCC FREESYSTEMCACHE ('ALL') -- clean system cache
DBCC FREESESSIONCACHE -- clean session cache
DBCC SHRINKDATABASE(tempdb, 10); -- shrink tempdb
DBCC SHRINKFILE ('tempdev') -- shrink db file
DBCC SHRINKFILE('temp2') -- shrink db file
DBCC SHRINKFILE('temp3') -- shrink db file
DBCC SHRINKFILE('temp4') -- shrink db file
DBCC SHRINKFILE('temp5') -- shrink db file
DBCC SHRINKFILE('temp6') -- shrink db file
DBCC SHRINKFILE('temp7') -- shrink db file
DBCC SHRINKFILE('temp8') -- shrink db file
--DBCC SHRINKFILE ('templog') -- shrink log file


GO

-- report the new file sizes
SELECT name, size
FROM sys.master_files
WHERE database_id = DB_ID(N'tempdb');
GO


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Query stats for cached execution plans
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT TOP 50
    creation_date = CAST(creation_time AS date),
    creation_hour = CASE
                        WHEN CAST(creation_time AS date) <> CAST(GETDATE() AS date) THEN 0
                        ELSE DATEPART(hh, creation_time)
                    END,
    SUM(1) AS plans
FROM sys.dm_exec_query_stats
GROUP BY CAST(creation_time AS date),
         CASE
             WHEN CAST(creation_time AS date) <> CAST(GETDATE() AS date) THEN 0
             ELSE DATEPART(hh, creation_time)
         END
ORDER BY 1 DESC, 2 DESC



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Search for text in Agent Job
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

use msdb

SELECT 
    [sJOB].[job_id] AS [JobID]
    , [sJOB].[name] AS [JobName]
    ,step.step_name
    ,step.command
FROM
    [msdb].[dbo].[sysjobs] AS [sJOB]
    LEFT JOIN [msdb].dbo.sysjobsteps step ON sJOB.job_id = step.job_id

WHERE step.command LIKE '%%'
ORDER BY [JobName]



------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- SSIS package Failure Investigation
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT      OPR.object_name
            , MSG.message_time
            , MSG.message
FROM        catalog.operation_messages  AS MSG
INNER JOIN  catalog.operations          AS OPR
    ON      OPR.operation_id            = MSG.operation_id
WHERE       MSG.message_type            = 120