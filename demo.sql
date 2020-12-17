use DemoAuctionTransaction;
go

-- Fetch a random product that has no bids          (347)
select P.ProductId
from Product as P
where not exists (
    select *
    from Bid as B
    where B.ProductId = P.ProductId
)
order by newid()
offset 0 rows
fetch first 1 row only

-- In the first query window create a transaction
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
end
else
begin
    select *
    from #LastBidForProduct
end

commit;



