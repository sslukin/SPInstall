sp_configure 'show advanced options', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_configure 'max degree of parallelism', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO

CREATE LOGIN [test\sp_setup] FROM WINDOWS;
GO

ALTER SERVER ROLE dbcreator ADD Member [test\sp_setup];
GO

ALTER SERVER ROLE securityadmin ADD Member [test\sp_setup];
GO