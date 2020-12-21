raiserror ('Wait! Execute one block at the time!', 16, 1);
return;

-- Introduction --
    /* Our goal for this demo is to find a correct - and possibly performant -
       way to apply specific business logic to our bids data. In particular, we
       need to forbid the insertion of bids that have a lower amount and a
       greater timestamp, and the solutions should be consistent at all
       concurrency levels.
       For example, the 2nd query of this section shouldn't be allowed.
    */

    insert into Bid (PersonId, ProductId, Amount, Timestamp)
    values (1, 1, 100, '2020-01-01 10:00:00');

    insert into Bid (PersonId, ProductId, Amount, Timestamp)
    values (1, 1, 80, '2020-01-01 10:00:01');

-- An attempt... --
    /* Let's first approach the problem as a typical developer would.
       For the sake of this example, let's select a random product which has at
       least four bids.
    */

    select ProductId
    from Bid
    group by ProductId
    having count(*) >= 4
    order by newid()
    offset 0 rows
    fetch first 1 row only

    -- I got 951, so I'll use this throughout the demo

    /* Let's develop a simple logic to solve the problem.
       We check whether the amount of the most recent bid for the given product
       is greater or equal than the current one. In such a case, we block the
       user. Otherwise, we insert the row.
    */

    declare @Amount money = (
        select Amount
        from Bid
        where ProductId = 951
        order by Timestamp desc
        offset 0 rows
        fetch first 1 row only
    );

    if @Amount >= 200.0000
    begin
        print 'There is already a higher bid, sorry!';
    end
    else
    begin
        insert into Bid (PersonId, ProductId, Amount, Timestamp)
        values (123, 951, 200.0000, sysdatetime());

        print 'Bid inserted successfully, thanks!';
    end

    /* This solution looks fine. However, after taking a closer look, we find
       out that between the data scan and the insert there is no guarantee that
       someone else isn't going to add a new row and invalidate our check,
       leaving the data in an inconsistent state.

       The following diagram represents an example of this scenario.

       Session 1 --- |READ (last = 170) --- |CHECK (OK) --- |INSERT (200)
       Session 2 ---------- |READ (last = 170) --- |CHECK (OK) --- |INSERT (190)
       Time      ----|------|---------------|------|--------|------|----------->

       To overcome this issue, we must ensure that no one will be able to take
       any decision based on that specific record while we are. To achieve this,
       we probably need to LOCK the record so that no one will be able to read
       it until our operation completes.

       In SQL Server (and other DBMS as well) has mainly two types of locks:
        - SHARED (S): Used by default when reading
        - EXCLUSIVE (X): Used by default when writing/updating

       A shared lock (S) is compatible with another shared lock. Hence, if a
       session is reading a piece of information, other sessions can read it at
       the same time. On the other hand, an exclusive lock (X) is incompatible
       with any other type of locks, both shared (S) and exclusive (X).

       By applying an exclusive lock we ensure that no one will be able to read
       our same object until we release it.
    */

-- The solution --
    /* By using the "with (xlock)" table hint we can ask SQL Server to read the
       data using an exclusive lock (X) instead of a shared one (S).
    */

    select Amount
    from Bid with (xlock)
    where ProductId = 951
    order by Timestamp desc
    offset 0 rows
    fetch first 1 row only;

    /* Although this looks correct, locks are released as soon as the scan
       completes. Therefore, we are as vulnerable as before in terms of
       consistency. To overcome this new problem, we need to wrap the logic in a
       transaction, so that the exclusive lock (X) is held until we eventually
       commit or rollback the transaction itself.
    */

    begin transaction;

    select Amount
    from Bid with (xlock)
    where ProductId = 951
    order by Timestamp desc
    offset 0 rows
    fetch first 1 row only;

    /* We can check that this transaction is holding the locks by looking at the
       system DMV sys.dm_tran_locks and filtering the current database id.
    */

    select
        request_session_id                  as [TheSession],
        request_type                        as [IsRequestingA],
        request_mode                        as [OfType],
        resource_description                as [ForTheObject],
        resource_type                       as [whichIsA],
        request_status                      as [AndItIsA]
    from sys.dm_tran_locks
    where resource_database_id = db_id()
    order by request_session_id, (
        case resource_type
            when 'DATABASE' then 1
            when 'OBJECT'   then 2
            when 'PAGE'     then 3
            when 'KEY'      then 4
                            else 5
        end
    );

    /* On my system I got this result:

       TheSession   IsRequestingA   OfType	ForTheObject    whichIsA	AndItIsA
       58           LOCK	        S	            	    DATABASE	GRANT
       58           LOCK	        IX	                    OBJECT	    GRANT
       58           LOCK	        IX      1:392           PAGE	    GRANT
       58           LOCK	        IX      1:417           PAGE	    GRANT
       58           LOCK	        IX      1:416           PAGE	    GRANT
       58           LOCK	        IX      1:419           PAGE	    GRANT
       58           LOCK	        IX      1:418           PAGE	    GRANT
       58           LOCK	        X	    (d344f69b7577)  KEY	        GRANT
       58           LOCK	        X	    (a83f3276fc11)  KEY	        GRANT
       58           LOCK	        X	    (cb89896b69df)  KEY	        GRANT
       58           LOCK	        X	    (54a829a0754e)  KEY	        GRANT

       The first row shows a shared lock on the database. It is pretty normal
       and means that as long as we have an open session on the database itself,
       no one can take an exclusive lock on it.

       It follows an intent exclusive lock (IX) on the object (the Bid table)
       and other locks on pages and keys. They mean that our session is holding
       an exclusive lock on some rows (keys) and some intent locks on their
       parents (pages and the table itself) to signal that it could eventually
       lock those as well.

       We can double-check that we have a lock on the resource by opening a new
       session and executing the same transaction.
       In the other SSMS/ADF tab run:
    */

    begin transaction;

    select Amount
    from Bid with (xlock)
    where ProductId = 951
    order by Timestamp desc
    offset 0 rows
    fetch first 1 row only;

    /* By running the query to the DMV again, we can see that now the other
       session requrested a lock and it's waiting. In this session run:
    */

    select
        request_session_id                  as [TheSession],
        request_type                        as [IsRequestingA],
        request_mode                        as [OfType],
        resource_description                as [ForTheObject],
        resource_type                       as [whichIsA],
        request_status                      as [AndItIsA]
    from sys.dm_tran_locks
    where resource_database_id = db_id()
    order by request_session_id, (
        case resource_type
            when 'DATABASE' then 1
            when 'OBJECT'   then 2
            when 'PAGE'     then 3
            when 'KEY'      then 4
                            else 5
        end
    );

    /* On my machine I got this result:

       TheSession	IsRequestingA	OfType	ForTheObject	whichIsA	AndItIsA
       58	        LOCK	        S	                   	DATABASE	GRANT
       58	        LOCK	        IX	                    OBJECT	    GRANT
       58	        LOCK	        IX	    1:392           PAGE	    GRANT
       58	        LOCK	        X	    (d344f69b7577)  KEY	        WAIT
       59	        LOCK	        S	                    DATABASE	GRANT
       59	        LOCK	        IX	                    OBJECT	    GRANT
       59	        LOCK	        IX	    1:392           PAGE	    GRANT
       59	        LOCK	        IX	    1:417           PAGE	    GRANT
       59	        LOCK	        IX	    1:416           PAGE	    GRANT
       59	        LOCK	        IX	    1:419           PAGE	    GRANT
       59	        LOCK	        IX	    1:418           PAGE	    GRANT
       59	        LOCK	        X	    (54a829a0754e)  KEY	        GRANT
       59	        LOCK	        X	    (d344f69b7577)  KEY	        GRANT
       59	        LOCK	        X	    (a83f3276fc11)  KEY	        GRANT
       59	        LOCK	        X	    (cb89896b69df)  KEY	        GRANT

       As you can see, session 58 (the other session) is waiting to lock key
       `d344f69b7577`, which is currently blocked by the transaction of session
       59, where the lock has been granted.

       Now we can safely apply any logic inside session 59 and be sure that no
       one else will mess up with our data while we are evaluating conditions!

       Let's commit the transaction in the current session:
    */

    commit;

    /* As you can see, as soon as you hit Run, the other session unlocked and
       the query completed.

       Let's close also the other session by committing the transaction:
    */

    commit;

-- Performance consideration --
    /* We solved the logic problem BUT we are not done yet... If you stop here,
       expect a call from your client/help desk/project manager very soon!

       Let's consider the structure of a record in the Bid table:

       Name         Type            Size
       BidId        int             4 bytes
       PersionId    int             4 bytes
       ProductId    int             4 bytes
       Amount       money           8 bytes
       Timestamp    datetime2 (7)   8 bytes
       -------------------------------------
       TOTAL                       28 bytes

       Since SQL Server saves data in 8KB pages, we can approximate that every
       page can fit (8192 / 28) ~ 290 rows, counting some page management
       overhead. Knowing there are 1000 rows and the fact that the primary key
       is clustered (the table is a b-tree) we can say that the whole table fits
       in (1000 / 290) 4 pages (leaves) + 1 page (root) = 5 pages.

       If you recall the previous query to DMV sys.dm_tran_lock, we were locking
       exactly 5 pages. This means that the session transaction is locking the
       entire table! We can prove this by querying a specific product in this
       session using the usual code:
    */

    begin transaction;

    select Amount
    from Bid with (xlock)
    where ProductId = 951
    order by Timestamp desc
    offset 0 rows
    fetch first 1 row only;

    /* And querying another product in the second session with the query: */

    begin transaction;

    select Amount
    from Bid with (xlock)
    where ProductId = 952
    order by Timestamp desc
    offset 0 rows
    fetch first 1 row only;

    /* As you can see, the second query is locked even though we are asking for
       different products!
       This behaviour is normal at this stage because of the operator SQL Server
       used to access the Bid Table: a clustered index scan. You can check it by
       asking SSMS/ADF to show the estimated/actual execution plan.

       What "clustered index scan" means is that SQL Server is going to read
       (and lock) every row in the table!

       To prevent that, we need to give SQL Server a way to seek directly into
       the row(s) it needs in order to execute the query. This tool is naturally
       an index!

       First, let's commit the transaction in both windows.
    */

        commit;

    /* The nonclustered (secondary) index we are going to create will need to be
       sorted first by ProductId and then by Timestamp, so that SQL Server is
       going to seek directly into the ProductId range and then directly into
       the first (or last - depending on the order) Timestamp.

       We can also include the Amount or other columns to prevent a Key Lookup
       operation, but given the fact that we expect only one row to come out
       from that query, we can ignore the small lookup cost vs. the storage cost
       of replicating another 8 bytes column, especially in larger tables.

       Our index will look something like this:
    */

    drop index if exists IX_Bid_ProductId_Timestmap
        on Bid;

    create index IX_Bid_ProductId_Timestmap
        on Bid(ProductId asc, Timestamp desc);

    -- Now, let's run the same transaction again and see what locks it takes:

    begin transaction;

    select Amount
    from Bid with (xlock)
    where ProductId = 951
    order by Timestamp desc
    offset 0 rows
    fetch first 1 row only;

    select
        request_session_id                  as [TheSession],
        request_type                        as [IsRequestingA],
        request_mode                        as [OfType],
        resource_description                as [ForTheObject],
        resource_type                       as [whichIsA],
        request_status                      as [AndItIsA]
    from sys.dm_tran_locks
    where resource_database_id = db_id()
    order by request_session_id, (
        case resource_type
            when 'DATABASE' then 1
            when 'OBJECT'   then 2
            when 'PAGE'     then 3
            when 'KEY'      then 4
                            else 5
        end
    );

    /* On my machine i got there results:

       TheSession	IsRequestingA	OfType	ForTheObject	whichIsA	AndItIsA
       59	        LOCK	        S	                    DATABASE	GRANT
       59	        LOCK	        IX	                  	OBJECT	    GRANT
       59	        LOCK	        IX	1:416               PAGE	    GRANT
       59	        LOCK	        IX	1:449               PAGE	    GRANT
       59	        LOCK	        X	(b108266cd5cb)      KEY	        GRANT
       59	        LOCK	        X	(cb89896b69df)      KEY	        GRANT

       As we can see,  now the transaction is holding a lock on two keys (rows)
       which are the row on the nonclustered index IX_Bid_ProductId_Timestmap we
       created and the row on the clustered index PK_Bid for the Key Lookup of
       the Amount column.

       We can prove this specific row is locked for other transactions by
       running the same query again in another window:
    */

    begin transaction;

    select Amount
    from Bid with (xlock)
    where ProductId = 951
    order by Timestamp desc
    offset 0 rows
    fetch first 1 row only;

    /* As you can see, the second query is left hanging by the lock of the first
       one.

       Let's now ensure the that other rows aren't blocked by running the
       following query:
    */

    begin transaction;

    select Amount
    from Bid with (xlock)
    where ProductId = 952
    order by Timestamp desc
    offset 0 rows
    fetch first 1 row only;

    /* You can also experiment with other rows and see the status of the DMV
       sys.dm_tran_locks. You'll notice that SQL Server now knows which rows we
       want to lock and act accordingly, effectively reducing blocking and
       enhancing the concurrency of our system in the case we have lots of
       different products.

       To clean up the sessions, commit all transactions.
    */

    commit;

-- Wrap up --
    /* Eventually, we can write a stored procedure that safely encapsulates our
       transactional safe - but still product-wise concurrent - business logic:
    */

    go
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
            end
            else
            begin
                select *
                from #LastBidForProduct
            end

            commit;
        end try
        begin catch
            while @@trancount > 0 rollback;
        end catch
    end
