CREATE TABLE [dbo].[Bid] (
    [BidId]     INT           IDENTITY (1, 1) NOT NULL,
    [PersonId]  INT           NOT NULL,
    [ProductId] INT           NOT NULL,
    [Amount]    MONEY         NOT NULL,
    [Timestamp] DATETIME2 (7) NOT NULL,
    CONSTRAINT [PK_Bid] PRIMARY KEY CLUSTERED ([BidId] ASC),
    CONSTRAINT [CK_Bid_PositiveAmount] CHECK ([Amount]>(0)),
    CONSTRAINT [FK_Bid_PersonId] FOREIGN KEY ([PersonId]) REFERENCES [dbo].[Person] ([PersonId]),
    CONSTRAINT [FK_Bid_ProductId] FOREIGN KEY ([ProductId]) REFERENCES [dbo].[Product] ([ProductId])
);


GO

