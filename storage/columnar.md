# Columnar

A lot of tools we use to store, manipulate and visualize data, have conditioned us to reason about data in a row-based fashion. It starts even before we ever touch a computer. Most of us learn to write left-to-right, top-to-bottom, appending line after line. It takes a bit of will to learn to reason about data in dimensions we're not used to.

Let's look at this table that contains a bunch of data on individual order items. The table is highly denormalized. A single row contains more than 30 columns.

| id  | placed_at        | customer_id | order_id  | product_id | price  | tax    |currency  | ... |
| --  | --------------  | --------   | ---------| --------- | -----  | -------| --------- | --- |
| 1   | 2014-1-1 00:01  | 859        | 1        | 210       | 50.00  | 10.50  | EUR       | ... |
| 2   | 2014-1-1 00:02  | 20151      | 1        | 169       | 20.00  | 4.20   | EUR       | ... |
| 3   | 2014-1-1 00:03  | 6          | 2        | 2         | 10.00  | 0.00   | USD       | ... |

To compare apples to apples, we'll first load this data in a row-based database. The database is set up to store each table in a dedicated file. Each file is chopped up into fixed-size blocks. Depending on the size of the rows, multiple rows might fit in a block, or a row might need multiple blocks to hold a complete row. All rows we persist are stored in the same file, conveniently named `table_orderitems.data`.

| block 0 | block 1 | block 2 | block.. |
| ------- | ------- | ------- | ------- |
| row 1   | row 2   | row 3   | row..   |

After loading the order items for the last ten years, the file has grown to take up 79GB on disk. We can now start questioning the data. We'll query the sum of all items sold, grouped by the currency.

```sql
select sum(price), currency
from order_items
group by currency;
```

Since the smallest unit of IO the database can work with is a block, the database will have to read all the blocks in the `table_orderitems.data` file when executing the query for the first time. Even though we only really care about the `price` and the `currency` columns.

Columnar databases optimize for this type of workloads by laying out data differently. If we load the order items data set in a columnar database, we also end up with a `table_orderitems.data` file, but the blocks contain column values instead of full rows. So instead of having to read the full 79GB from disk, our query can now only read the blocks that contain the values of the `price` and `currency` columns. Meaning the query can now be satisfied by reading only a fraction of the data from disk, instead of the full 79GB.

| block 0  | block 1  | block 3  | block..  |
| -------  | -------  | -------  | -------  |
| column 0 | column 0 | column 0 | column.. |

This makes columnar databases extremely efficient for read workloads that only require a small set of columns, but inefficient for those that read full rows. Efficient for the type of queries you often find in reporting, business intelligence or analytics - or OLAP in short. Inefficient for those you find in a transaction processing application - OLTP. When your queries require a large set of columns you will often be better off sticking to a row-based database.

Redshift stores tables in their own file in the data directory. However, the file won't be named `table_orderitems.data`. Redshift assigns each file an internally assigned `filenode` number. You can query the catalog tables to find out the file name, but Redshift won't allow you access to the underlying storage to verify if the file really exists on disk.

```sql
select relname, relfilenode
from pg_catalog.pg_class
where relname = 'order_items';
```

| relname     | relfilenode |
| ----------  | ------------|
| order_items | 174738      |

As we learned earlier, files are divided up into blocks, and blocks contain column values. We can peek inside a file and see how many blocks are used per column.

```sql
select col, count(*) AS blocks
from stv_blocklist, stv_tbl_perm
where stv_blocklist.tbl = stv_tbl_perm.id
  and stv_blocklist.slice = stv_tbl_perm.slice
  and stv_tbl_perm.id = 174738
group by col
order by col;
```

| col | blocks |
| --- | ------ |
| 0   | 624    |
| 1   | 1672   |
| 2   | 1304   |
| ... | ...    |
| 30  | 28     |
| 31  | 28     |
| 32  | 4940   |

The result shows 33 columns, 3 more than expected. The last three columns are hidden columns used by Redshift: `insert_xid`, `delete_xid` and `row_id`.

Now that we know the number of blocks used to store a single column, we're still missing one piece of vital information: the block size. Redshift's user interaction layer is based on PostgreSQL. So if you have experience tweaking and running a PostgreSQL installation, you might remember the `show block_size` command off the top of your head. However, executing this command in Redshift - even when we're logged in as root, returns an error saying we have insufficient permissions. A good reminder Redshift is a piece of proprietary technology running on rented infrastructure. Fortunately the Redshift docs state more than once that the block size is set to 1MB.

In databases designed for OLTP workloads you will find far smaller block sizes (2KB, 4KB, 8KB and up). Smaller block sizes yield good results when you read and write small pieces of data and do random IO. Large block sizes perform better when you write and read large pieces of data in a sequential fashion. They waste less space storing block meta data and reduce the number of IO operations.

If you multiply the number of blocks by the block size, you end up with the actual space on disk being used to store a column or a table. A block size of 1MB makes the calculation very simple.
