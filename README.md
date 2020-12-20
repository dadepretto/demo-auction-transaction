# demo-auction-transaction
This demo is about SQL Transactions and locking/blocking mechanisms by giving an example on how those could be used in order to protect the data integrity of the Bid table of a fictional auction website.
The demo also focus on performance and concurrency by explaining how you can use an index to improve these aspects.

## Requirements
To run this demo you need a SQL Server instance (i wrote it on 2019) and a way to query your database using multiple sessions (usually SQL Server Management Studio or Azure Data Factor)

## Steps
To run this demo you need to:
1. create a new empty database on you choosen SQL Server intance
2. deploy the SQL Server Database Project located in the `./database` folder (`./database/DemoAuctionTransaction.sqlproj` file).
3. load the demo data using the `./demo-data/load-data.sql` script, after changing paths to the source `.csv` files accordingly to you file system structure
3. Follow the demo in the `./demo.sql` file