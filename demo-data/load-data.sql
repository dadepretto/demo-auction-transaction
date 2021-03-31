bulk insert [dbo].[Person]
from '<path_to_folder>/Person.csv' -- eg. '/var/opt/mssql/staging/Person.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);

bulk insert [dbo].[Product]
from '<path_to_folder>/Product.csv' -- eg. '/var/opt/mssql/staging/Product.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);

bulk insert [dbo].[Bid]
from '<path_to_folder>/Bid.csv' -- eg. '/var/opt/mssql/staging/Bid.csv'
with (
    format = 'csv',
    firstrow = 2,
    maxerrors = 0
);
