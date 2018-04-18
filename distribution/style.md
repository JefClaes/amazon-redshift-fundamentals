# Distribution style

When you insert data into a table, the leader node decides how it is distributed over the slices in the Redshift cluster. When you create a table, you can choose between three distribution styles: even, key and all. The way a table is distributed over the cluster has a big impact on performance. Ideally, you want to distribute data evenly across the cluster while collocating related data. When a slice executing a query requires data that lives somewhere else, Redshift is forced to talk to other nodes in its network and copy some of their data over. In any distributed application, you want to distribute work in a way that allows each node to focus on the work at hand by keeping the overhead of communication to a bare minimum.

## Even distribution

Using this style, the leader node will distribute the table over all the slices in the cluster in a round-robin fashion.

The denormalized `order_items` table we used earlier is a good candidate for an even distribution style. If we write a query that counts all the order items that were sold for 50 EUR or higher, all the slices would be put to work, achieving maximum parallelism. Even distribution generally works very well when there is no need to join the table.

When you don't specify a style when creating a table, this is the default.

## Key distribution

Using key distribution, a single column decides how the table is distributed over the slices. Try to choose a key that distributes the data evenly over the slices, while considering which tables it will often be joined with.

If, instead of a denormalized `order_items`, we would model it as a star schema, we might end up with the tables `orders`, `order_items`, `customers`, `products` etc. With this model, we know that we would need to join the tables `orders` and `order_items` almost always. Here it makes sense to define `orders.id` and `order_items.order_id` respectively as the distribution key, ensuring that there is no data redistribution required before being able to perform the join.

Making these decisions, you want to be informed about the queries to expect and the data distribution of the tables. The first one requires you to actually talk to business owners, the second one can be acquired by querying existing data.

```sql
select order_id, count(*) as count
from order_items
group by 1
order by 2 desc
```

| order_id | count  |
| -------- | ------ |
| 1528     | 28     |
| 5878     | 28     |
| 2001     | 27     |
| ...      | ...    |

When you start searching for a good distribution of the data in certain columns, you will most likely find some interesting insights.

For example, looking at the order items per currency, we can see that one currency dominates sales. Fair enough, we only started selling outside of Europe the last few months. Choosing the `currency` as the distribution style distributes the data unevenly, introducing skew, turning specific slices into hot-spots doing more work than others.

```sql
select currency, count(*) AS count
from order_items
group by 1
order by 2 desc
```

| currency    | count    |
| ---------   | -------- |
| EUR         | 81201057 |
| USD         | 32481    |
| JPY         | 15887    |
| ...         | ...      |

Another example would be the `tax` column. Looking into the data, we learned that some regions are tax exempt, making this column a disasterous distribution key. Every nullable column should raise a red flag when shopping for a distribution style.

Another anti-pattern to look out for is having a date- or timestamp the distribution key. A query that aggregates data in a small date range might evaluate on a single slice, instead of distributing the work over multiple slices.

The distribution key is defined when creating the table.

```sql
create table order_items (
  id int not null,
  added_at timestamp not null,
  ... )
diststyle key
distkey (id)
```

When working with an existing data set, or when testing out different models, we can use the system table `svv_table_info` for any skew that looks off. The `skew_rows` column tell us the ratio of the number of rows in the slice with the most rows to the number of rows in the slice with the least rows.

Assuming we run a single node with two slices. If we only had 3 customers, and we would make `customer_id` the distribution key, we would end up with a ratio of 2 to 1.

```sql
select table, skew_rows
from svv_table_info
```

## All distribution

In a star schema, you'll notice that it's more often than not impossible to optimize for all cases. The all distribution can come in handy here. With this distribution style, a table is distributed to all nodes. This works really well for smaller tables that don't change much. Distributing a table to each node will improve query performance when this table is often included in a join, but importing the data will also take much longer because it needs to be distributed to each node.

Note that the tables are distributed to each node, not each slice. So load times of tables using the all distribution will be very different when you have a cluster with 16 small nodes, compared to a cluster with 2 big nodes, even though both configurations add up to the same amount of slices.

The all distribution style is defined when creating the table.

```sql
create table products (
  id int not null,
  placed_at timestamp not null,
  ... )
diststyle all
```
