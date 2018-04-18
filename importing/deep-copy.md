# Deep Copy

When the source database contains tables where rows change, and you can afford to have somewhat stale data or the data doesn't change often, you can consider replacing the destination table as a whole.

When a new snapshot of the source table is uploaded, you can truncate the destination table and copy the file into the table.

```sql
-- delete table
truncate table products;
-- load table
copy products
from 's3://webshop-archive/products/v1/2017/12/21/snapshot-1.zip'
iam_role 'arn:aws:iam:123456:role/dwimport';
```

This has one caveat though. The `TRUNCATE` command commits immediately and can not be rolled back. Between truncating the destination table and copying the new data from the source file, the table is empty, which could result in inconsistent results.

By introducing a staging table and some intermediary steps, it's possible to replace the table's contents as one single atomic operation. This ensures queries never get to see an empty table.

- Truncate the staging table
- Begin a new transaction
- Copy the data to the staging table
- Rename the destination table, by postfixing it with `old`
- Rename the staging table to the destination table by removing the `staging` postfix
- Rename the old table, by changing the `old` postfix to `staging`
- Commit the transaction

```sql
-- truncate staging table
truncate table products_staging;

-- replace destination table
begin;

copy products_staging
from 's3://webshop-archive/products/v1/2017/12/21/snapshot-1.zip'
iam_role 'arn:aws:iam:123456:role/dwimport';

alter table products          rename to products_old;
alter table products_staging  rename to products;
alter table products_old      rename to products_staging;

commit;
```