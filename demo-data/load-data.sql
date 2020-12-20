bulk insert Person
from '<path_to_folder>/Person.csv' -- eg. '/var/opt/mssql/staging/Person.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);

bulk insert Product
from '<path_to_folder>/Product.csv' -- eg. '/var/opt/mssql/staging/Product.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);

bulk insert Bid
from '<path_to_folder>/Bid.csv' -- eg. '/var/opt/mssql/staging/Bid.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);
