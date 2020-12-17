CREATE TABLE [dbo].[Product] (
    [ProductId]   INT            IDENTITY (1, 1) NOT NULL,
    [DisplayName] NVARCHAR (255) NOT NULL,
    [Description] NVARCHAR (MAX) NOT NULL,
    CONSTRAINT [PK_Product] PRIMARY KEY CLUSTERED ([ProductId] ASC)
);


GO

