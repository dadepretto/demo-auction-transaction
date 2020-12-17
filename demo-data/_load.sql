bulk insert Person
from '/var/opt/mssql/staging/Person.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);

bulk insert Product
from '/var/opt/mssql/staging/Product.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);

bulk insert Bid
from '/var/opt/mssql/staging/Bid.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);
