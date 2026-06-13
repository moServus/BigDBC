-- Demo schema for SQL SPA Explorer — SQL Server
-- Executed by entrypoint.sh via sqlcmd after the server is ready.

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SqlSpaExplorer')
    CREATE DATABASE SqlSpaExplorer;
GO

USE SqlSpaExplorer;
GO

IF OBJECT_ID('dbo.products',   'U') IS NULL AND
   OBJECT_ID('dbo.categories', 'U') IS NULL
BEGIN

    CREATE TABLE dbo.categories (
        id          INT IDENTITY(1,1) PRIMARY KEY,
        name        NVARCHAR(100) NOT NULL,
        description NVARCHAR(MAX)
    );

    CREATE TABLE dbo.products (
        id          INT IDENTITY(1,1) PRIMARY KEY,
        category_id INT REFERENCES dbo.categories(id),
        name        NVARCHAR(200) NOT NULL,
        price       DECIMAL(10, 2) NOT NULL,
        stock       INT NOT NULL DEFAULT 0,
        created_at  DATETIME2 DEFAULT GETDATE()
    );

    INSERT INTO dbo.categories (name, description) VALUES
        ('Electronics', 'Gadgets and devices'),
        ('Books',       'Printed and digital media'),
        ('Clothing',    'Apparel and accessories');

    INSERT INTO dbo.products (category_id, name, price, stock) VALUES
        (1, 'Laptop',      999.99, 50),
        (1, 'Headphones',  149.99, 200),
        (2, 'Clean Code',   39.99, 100),
        (3, 'T-Shirt',      19.99, 500);

END
GO
