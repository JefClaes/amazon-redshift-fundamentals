# Block metadata

When Redshift writes blocks, it stores a bit of meta data for each block. A vital piece of information stored is the minimum and maximum value in each block, creating zone maps. Zone maps can speed up queries drastically by allowing Redshift to skip whole blocks while scanning for data.

As an example, let's say we want to query how many order items were placed in 2018.

```sql
select count(*)
from order_items
where placed_at between '2018-1-1' and '2019-1-1'
```

We can query the block meta data for the `placed_at` column.

```sql
select
  blocknum as block,
  minvalue as min,
  maxvalue as max
from stv_blocklist, stv_tbl_perm
where stv_blocklist.tbl = stv_tbl_perm.id
  and stv_blocklist.slice = stv_tbl_perm.slice
  and stv_tbl_perm.name = 'order_items'
  and stv_blocklist.col = 1 /* placed_at */
order by blocknum
```

After translating the min and max value, the result set looks something like this.

| block | min       | max       |
| ----- | --------- | --------- |
| 0     | 2014-1-1  | 2014-2-3  |
| 1     | 2014-2-3  | 2014-3-8  |
| ...   | ...       | ...       |
| 1500  | 2018-1-1  | 2018-1-11 |
| 1501  | 2018-1-11 | 2018-1-25 |

Having this piece of information allows Redshift to skip all blocks except for block 1500 and 1501. Admittedly, because the values of the `placed_at` column are sequential, the efficiency of this query is phenomenal.

If we look at another column that has no sequential order, like `price`, the use of zone maps becomes way less efficient.

| block | min      | max      |
| ----- | ---------| ---------|
| 0     | 1        | 3499     |
| 1     | 1        | 2999     |
| ...   | ...      | ...      |
| 400   | 1        | 2875     |
| 401   | 1        | 3889     |

If we query the `order_items` table for items that cost less than 100 EUR, we can't skip any blocks and will have to scan each block individually. If we were interested in items that cost more than 3000 EUR, we would be able to skip roughly 50% of all blocks.
