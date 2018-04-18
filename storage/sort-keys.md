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

## Compound

Since there is more than one column in the predicate, we'll compose a compound sort key containing both `customer_id` and `product_id`. The compound key looks just like the result of an `order by` on two columns.

| block | customer_id  | product_id |
| ----- | -----------  | ---------- |
| 1     | 1            | 1          |
| 1     | 1            | 2          |
| 1     | 1            | 3          |
| 1     | 1            | 4          |
| 2     | 2            | 1          |
| 2     | 2            | 2          |
| 2     | 2            | 3          |
| 2     | 2            | 4          |
| 3     | 3            | 1          |
| 3     | 3            | 2          |
| 3     | 3            | 3          |
| 3     | 3            | 4          |
| 4     | 4            | 1          |
| 4     | 4            | 2          |
| 4     | 4            | 3          |
| 4     | 4            | 4          |

Using this sorting style, Redshift only needs to read a single block; the first one. The zone maps contain enough data to quickly eliminate the other blocks.

However, if we would only count the `product_id` values that equal 3, the whole sort key becomes way less efficient. Redshift is forced to scan all blocks when the sort key prefix is not involved in the predicate.

## Interleaved

When you want to assign each column in the sort key an equal weight, you can use an interleaved sort key instead of a compound one. Redshift will reduce multiple columns to one dimension, while preserving locality of the data points. Sorting and querying an interleaved key can be visualized as laying values out over a multi-dimensional graph, looking at the data points as coordinates of a map, chopping up the map in blocks.

```txt
  ProductId
  |              |
4 | (1,4)  (2,4) | (3,4) (4,4)
  |              |
3 | (1,3)  (2,3) | (3,3) (4,3)
  |--------------| -------------
2 | (1,2)  (2,2) | (3,2) (4,2)
  |              |
1 | (1,1)  (2,1) | (3,1) (4,1)
  |_ _ _ _ _ _ _ | _ _ _ _ _ _ _  CustomerId
    1      2      3    4
```

| block | customer_id | product_id |
| ----- | ----------  | ---------- |
| 1     | 1           | 1          |
| 1     | 1           | 2          |
| 1     | 2           | 1          |
| 1     | 2           | 2          |
| 2     | 1           | 3          |
| 2     | 1           | 4          |
| 2     | 2           | 3          |
| 2     | 2           | 4          |
| 3     | 3           | 1          |
| 3     | 3           | 2          |
| 3     | 4           | 1          |
| 3     | 4           | 2          |
| 4     | 3           | 3          |
| 4     | 3           | 4          |
| 4     | 4           | 3          |
| 4     | 4           | 4          |

If we now query for a specific `customer_id`, Redshift will have to read two blocks. When we query a specific `product_id`, Redshift will also have to read two blocks. However, when we query a specific `customer_id` for a specific `product_id`, Redshift will only need to read one block. When all the columns in the sort key are specified, we can pinpoint the exact location of the data. The less columns in the sort keys we specify in the predicate, the harder it becomes to know the exact location of the data. Once again, it's very much like a spatial search. If I'd tell you the coordinate of a location with a partial coordinate of (0, ?), you would know the location has to be somewhere on the equator, but you wouldn't be able to pinpoint the exact location.