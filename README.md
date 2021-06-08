# demo-auction-transaction

This demo is about SQL Transactions and locking/blocking mechanisms.
It consists of an example of how to use transactions to protect the data
integrity of the Bid table of a fictional auction website.
It also focuses on performance and concurrency by explaining how you can use an
index to improve these aspects.

## Requirements

To run this demo, you need a SQL Server instance (I wrote it on 2019) and a way
to query your database using multiple sessions (usually SQL Server Management
Studio or Azure Data Studio).

## Steps

To run this demo you need to:

1. create a new empty database on your chosen SQL Server instance;
2. deploy the SQL Server Database Project located in the `./database` folder
   (`./database/DemoAuctionTransaction.sqlproj` file);
3. load the demo data using the `./demo-data/load-data.sql` script, after
   changing paths to the source `.csv` files accordingly to your file system
   structure;
4. follow the demo in the `./demo.sql` file.
