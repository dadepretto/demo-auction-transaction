CREATE TABLE [dbo].[Person] (
    [PersonId]  INT            IDENTITY (1, 1) NOT NULL,
    [FirstName] NVARCHAR (255) NOT NULL,
    [LastName]  NVARCHAR (255) NOT NULL,
    CONSTRAINT [PK_Person] PRIMARY KEY CLUSTERED ([PersonId] ASC)
);


GO

