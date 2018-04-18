# Sort keys

In a row-based database, indexes are used to improve query performance. An index is a data structure that allows for faster data retrieval. A clustered index defines in which order rows are stored on disk, while a non-clustered index is a separate data structure sitting next to a table. It stores a small set of individual columns together with a pointer to the full row in the table. This means the database can scan this small tree structure instead of the complete table.

For example, 7 values of the `price` column might translate to this small tree structure which is faster to scan than a list of 7 values.

```txt
              | 10
      | 20 -- |
      |       | 30
50 --
      |       | 60
      | 72 -- |
              | 100
```

While indexes can make all the difference in a row-based database, you can't just try to make a row-based database behave like a columnnar database by adding indexes to each column. Indexes need to be maintained with each write to a table. The cost of both IO in time and storage increases with each index added.

Redshift doesn't implement non-clustered indexes since each column almost acts as its own index. However as proven by the `placed_at` range query earlier, the order of column values in blocks makes a big difference in query performance by making zone maps extremely efficient. Redshift allows you to define a sort key, similar to a clustered index, deciding which column values will be sorted on disk writes. The `order_items` sort key was created on the `placed_at` column, since we tend to look at a lot of our data month by month.

```sql
create table order_items (
  id        integer   not null,
  placed_at timestamp not null,
  ...
)
sortkey (placed_at)
```

The sort key can either be a single column or a composition of multiple columns.

There are two styles of sort keys: compound and interleaved. To have a benchmark, we'll use a query that counts the number of items sold where the `customer_id = 1`  and the `product_id = 2`.

```sql
select count(*)
from order_items
where customer_id = 1 and product_id = 2
```