/*

JUST RUN THE SCRIPT, unless it is a cluster.

Create Operator 'DBA Email (non-emergency)' for email address DBAEmail@hpplans.com
Enable Database Mail XPs
Create Database Mail/Profile accounts
Create the Alerts for Severity 17-25, 823,824,825
Enables all alerts, except 20, and associates the notification to the operator
Enables Mail Profile in SQL Server Agent
Unchecks "Limit the size of Job History" in SQL Agent (another job will handle that)

*/

---------------------------------------------------------------------------------------------------------------------------------------
-- Create Operator 'DBA Email (non-emergency)' for email address DBAEmail@hpplans.com

USE [msdb]
GO


/****** Object:  Operator [DBA Email (non-emergency)]    Script Date: 3/19/2019 11:24:03 AM ******/
EXEC msdb.dbo.sp_add_operator @name=N'DBA Email (non-emergency)', 
		@enabled=1, 
		@weekday_pager_start_time=80000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=80000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=80000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'DBAEmail@hpplans.com', 
		@category_name=N'[Uncategorized]'
GO

---------------------------------------------------------------------------------------------------------------------------------------
--Enable Database Mail XPs

sp_configure 'Show Advanced Options', 1 
reconfigure 
go
sp_configure 'Database Mail XPs', 1 
reconfigure
go
sp_configure 'Show Advanced Options', 0 
reconfigure
go

---------------------------------------------------------------------------------------------------------------------------------------
--Create Database Mail/Profile accounts

-- Get the server name
DECLARE @ServerName sysname = (SELECT CONVERT(nvarchar,SERVERPROPERTY('MachineName')));
DECLARE @ServerEmail varchar(255)
DECLARE @ServerDisplayName varchar(255)

Set @ServerEmail= 'DBMail@hpplans.com'
Set @ServerDisplayName ='DBMail ' + @ServerName

-- Note: server HPMAIL is actually hpmail.healthpartners.org.
EXECUTE msdb.dbo.sysmail_add_account_sp
    @account_name = 'DBMail',
    @description = 'Account used for all Database Mail Profiles',
    @email_address = @ServerEmail,
    @replyto_address = 'donotreply@hpplans.com',
    @display_name = @ServerDisplayName,
    @mailserver_name = 'HPMAIL'

-- Create a Database Mail profile
EXECUTE msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'DBMailPublicProfile',
    @description = 'Default public profile for all users'

-- Add the account to the profile
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'DBMailPublicProfile',
    @account_name = 'DBMail',
    @sequence_number = 1

-- Grant access to the profile to all msdb database users
EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
    @profile_name = 'DBMailPublicProfile',
    @principal_name = 'public',
    @is_default = 1

-- Send a test email
EXECUTE msdb.dbo.sp_send_dbmail
    @recipients = 'DBAEmail@hpplans.com',
    @subject = 'Test database email from new SQL Server',
    @query = 'SELECT SERVERPROPERTY(''MachineName'')'

---------------------------------------------------------------------------------------------------------------------------------------
-- This creates the Alerts for Severity 17-25, 823,824,825
-- It enables all alerts, except 20, and associates the notification to the operator

USE [msdb];
GO

SET NOCOUNT ON;


-- Change @OperatorName as needed
DECLARE @OperatorName sysname = N'DBA Email (non-emergency)';

-- Change @CategoryName as needed
DECLARE @CategoryName sysname = N'SQL Server Agent Alerts';

-- Make sure you have an Agent Operator defined that matches the name you supplied
IF NOT EXISTS(SELECT * FROM msdb.dbo.sysoperators WHERE name = @OperatorName)
	BEGIN
		RAISERROR ('There is no SQL Operator with a name of %s' , 18 , 16 , @OperatorName);
		RETURN;
	END

-- Add Alert Category if it does not exist
IF NOT EXISTS (SELECT *
               FROM msdb.dbo.syscategories
               WHERE category_class = 2  -- ALERT
			   AND category_type = 3
               AND name = @CategoryName)
	BEGIN
		EXEC dbo.sp_add_category @class = N'ALERT', @type = N'NONE', @name = @CategoryName;
	END

-- Get the server name
DECLARE @ServerName sysname = (SELECT CONVERT(nvarchar,SERVERPROPERTY('MachineName')));


-- Alert Names start with the name of the server 
DECLARE @Sev17AlertName sysname = @ServerName + N' Alert - Sev 17 Error: Insufficient Resource';
DECLARE @Sev18AlertName sysname = @ServerName + N' Alert - Sev 18 Error: Nonfatal Internal Error';  
DECLARE @Sev19AlertName sysname = @ServerName + N' Alert - Sev 19 Error: Fatal Error in Resource';
DECLARE @Sev20AlertName sysname = @ServerName + N' Alert - Sev 20 Error: Fatal Error in Current Process';
DECLARE @Sev21AlertName sysname = @ServerName + N' Alert - Sev 21 Error: Fatal Error in Database Process';
DECLARE @Sev22AlertName sysname = @ServerName + N' Alert - Sev 22 Error: Fatal Error: Table Integrity Suspect';
DECLARE @Sev23AlertName sysname = @ServerName + N' Alert - Sev 23 Error: Fatal Error Database Integrity Suspect';
DECLARE @Sev24AlertName sysname = @ServerName + N' Alert - Sev 24 Error: Fatal Hardware Error';
DECLARE @Sev25AlertName sysname = @ServerName + N' Alert - Sev 25 Error: Fatal Error';
DECLARE @Error823AlertName sysname = @ServerName + N' Alert - Error 823: The operating system returned an error';
DECLARE @Error824AlertName sysname = @ServerName + N' Alert - Error 824: Logical consistency-based I/O error';
DECLARE @Error825AlertName sysname = @ServerName + N' Alert - Error 825: Read-Retry Required';
--DECLARE @Error832AlertName sysname = @ServerName + N' Alert - Error 832: Constant page has changed';
--DECLARE @Error855AlertName sysname = @ServerName + N' Alert - Error 855: Uncorrectable hardware memory corruption detected';
--DECLARE @Error856AlertName sysname = @ServerName + N' Alert - Error 856: SQL Server has detected hardware memory corruption, but has recovered the page';

-- Sev 17 Error: Insufficient Resource
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev17AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev17AlertName, 
				  @message_id = 0, @severity = 17, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev17AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev17AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 18 Error: Nonfatal Internal Error
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev18AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev18AlertName, 
				  @message_id = 0, @severity = 18, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev18AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev18AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 19 Error: Fatal Error in Resource
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev19AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev19AlertName, 
				  @message_id = 0, @severity = 19, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev19AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev19AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 20 Error: Fatal Error in Current Process
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev20AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev20AlertName, 
				  @message_id = 0, @severity = 20, @enabled = 0, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000'

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev20AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev20AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 21 Error: Fatal Error in Database Process
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev21AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev21AlertName, 
				  @message_id = 0, @severity = 21, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev21AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev21AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 22 Error: Fatal Error Table Integrity Suspect
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev22AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev22AlertName, 
				  @message_id = 0, @severity = 22, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev22AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev22AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 23 Error: Fatal Error Database Integrity Suspect
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev23AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev23AlertName, 
				  @message_id = 0, @severity = 23, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev23AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev23AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 24 Error: Fatal Hardware Error
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev24AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev24AlertName, 
				  @message_id = 0, @severity = 24, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1,
				  @category_name = @CategoryName, 
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev24AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev24AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Sev 25 Error: Fatal Error
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Sev25AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Sev25AlertName, 
				  @message_id = 0, @severity = 25, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName,
				  @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Sev25AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Sev25AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END

-- Error 823 Alert added on 8/11/2014

-- Error 823: Operating System Error
-- How to troubleshoot a Msg 823 error in SQL Server	
-- http://support.microsoft.com/kb/2015755
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error823AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error823AlertName, 
				  @message_id = 823, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName, 
				  @job_id  = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error823AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error823AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END
	
-- Error 824 Alert added on 8/11/2014

-- Error 824: Logical consistency-based I/O error
-- How to troubleshoot Msg 824 in SQL Server
-- http://support.microsoft.com/kb/2015756
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error824AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error824AlertName, 
				  @message_id = 824, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName, 
				  @job_id  = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error824AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error824AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END


-- Error 825: Read-Retry Required
-- How to troubleshoot Msg 825 (read retry) in SQL Server
-- http://support.microsoft.com/kb/2015757
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = @Error825AlertName)
	EXEC msdb.dbo.sp_add_alert @name = @Error825AlertName, 
				  @message_id = 825, @severity = 0, @enabled = 1, 
				  @delay_between_responses = 900, @include_event_description_in = 1, 
				  @category_name = @CategoryName, 
				  @job_id  =N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS(SELECT *
		      FROM dbo.sysalerts AS sa
              INNER JOIN dbo.sysnotifications AS sn
              ON sa.id = sn.alert_id
              WHERE sa.name = @Error825AlertName)
	BEGIN
		EXEC msdb.dbo.sp_add_notification @alert_name = @Error825AlertName, @operator_name = @OperatorName, @notification_method = 1;
	END

---------------------------------------------------------------------------------------------------------------------------------------	
--  Enables Mail Profile in SQL Server Agent
--  Unchecks "Limit the size of Job History" in SQL Agent (another job will handle that)

USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1, 
		@databasemail_profile=N'DBMailPublicProfile', 
		@use_databasemail=1
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows=-1, 
		@jobhistory_max_rows_per_job=-1, 
		@email_save_in_sent_folder=1, 
		@databasemail_profile=N'DBMailPublicProfile', 
		@use_databasemail=1
GO
---------------------------------------------------------------------------------------------------------------------------------------	

-- Review and COMPLETE POST_SQL_INSTALL_Guidelines_2.DOCX
-- Review and COMPLETE POST_SQL_INSTALL_Guidelines_3.sql [Based on particular SQL Server requirements]


---------------------------------------------------------------------------------------------------------------------------------------	
-- Added by Joe McAnally on 2019-oct-15
EXEC SP_CONFIGURE 'show advanced options',1
GO
RECONFIGURE
GO
EXEC SP_CONFIGURE 'Agent XPs',1
GO
RECONFIGURE
GO
EXEC SP_CONFIGURE 'show advanced options',0
GO
RECONFIGURE
GO
---------------------------------------------------------------------------------------------------------------------------------------	
