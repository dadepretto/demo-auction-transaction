create or alter procedure [dbo].[insertBid] (
    @PersonId int,
    @ProductId int,
    @Amount money
)
as
begin
    set transaction isolation level serializable;

    begin try
        begin transaction;

        select top 1 *
        into #LastBidForProduct
        from Bid with (xlock)
        where ProductId = @ProductId
        order by Timestamp

        if @Amount > isnull((select Amount from #LastBidForProduct), 0)
        begin
            insert into Bid (PersonId, ProductId, Amount, Timestamp)
            output inserted.*
            values (@PersonId, @ProductId, @Amount, sysdatetime());
            
            commit;

            return 0;
        end
        else
        begin
            select *
            from #LastBidForProduct;

            commit;

            return 1;
        end
    end try
    begin catch
        while @@trancount > 0
          rollback;

        return -1;
    end catch

end
