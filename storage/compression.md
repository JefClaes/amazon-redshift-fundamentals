# Compression

When we use compression, we choose to pay a higher price of compute in order to reduce the cost of storing and shuffling data around by making our data smaller. When you consider your application to be IO bound, making use of compression might have a big impact. Whether or not compression will bring the improvements you hope for, depends on whether the data suits the chosen compression algorithm.

Row-based databases often support compression on the row- or block level. One way to compress a sample data set containing 4 rows, is by building a dictionary which stores each unique value together with an index, and replacing the values inside the rows with its index.

```txt
# Uncompressed

| price  | tax    | currency |
| -----  | -------| -------- |
| 50.00  | 10.00  | EUR      |
| 50.00  | 10.00  | USD      |
| 50.00  | 10.00  | EUR      |
| 100.00 | 20.00  | EUR      |

# Dictionary

| index | value  |
| ----- | ------ |
| 0     | 50.00  |
| 1     | 10.00  |
| 2     | 100.00 |
| 3     | 20.00  |
| 4     | EUR    |
| 5     | USD    |

# Compressed

| price | tax    | currency |
| ----- | -------| -------- |
| 0     | 1      | 4        |
| 0     | 1      | 5        |
| 0     | 1      | 4        |
| 2     | 3      | 4        |
```

The dictionary will be stored on the same block as the rows as a part of the header. Keeping the size of the dictionary in mind, this algorithm compresses the contents of the block by approximately 35%.

To improve the compression ratio, we need to make the dictionary more efficient. We can consider the dictionary more efficient when it is smaller relative to the size of the data set. This can be achieved by feeding the algorithm data that's more homogeneous and contains fewer distinct values. These are two requirements that columnar storage can easily satisfy.

Because columnar databases group column values together, the values share the same type, making the data set to compress homogeneous. When the data set is guaranteed to be of single type, we can - instead of a one-size-fits-all algorithm - choose a compression algorithm that best suits the data.

There are a few obvious examples of this. Timestamps are highly unique, but if we store the differences between each timestamp, we can save a lot of space. Long varchars, like the body of a tweet or a blog post, can benefit from a compression technique that stores individual words in a separate dictionary. For types like a boolean, you might want to avoid compression as a whole, the values are not going to get smaller than a single bit.

Looking back to the dictionary approach, there's one other obvious change we can make to make it more efficient: make the blocks larger. The more data we compress, the better the odds of it containing the same value more than once. Redshift uses a block size of 1MB, yielding a much higher compression ratio than your day-to-day OLTP row-based database.

7 types of compression encoding are supported:

- RAW
- Byte-Dictionary
- Delta
- LZO
- Mostly
- Runlength
- Text255 and Text32k
- Zstandard

This gives us quite a few options to choose from, which might feel like a time-consuming task. However, Redshift doesn't really need us to get that intimate with our data set. Out of the box, there are tools available that help select the right compression encoding.

If you already have a table that contains a usable amount of data, Redshift can analyze the columns for you and advise an optimal encoding.

```sql
analyze compression order_items;
```

| table       | column      | encoding | est_reduction_pct |
| ----------- | ----------- | -------- | ----------------- |
| order_items | id          | delta    | 0.00              |
| order_items | placed_at   | zstd     | 39.83             |
| order_items | customer_id | zstd     | 44.39             |
| ...         | ...         | ...      | ...               |

Pay attention though. The `ANALYZE COMPRESSION` command acquires an exclusive lock, preventing concurrent reads and writes against the table.

When you bulk import data into a table using the `COPY` command - which is the recommended way, Redshift will automatically apply compression if all conditions are met. For automatic compression to be applied, the destination table needs to be empty, all columns need to have RAW or no encoding applied and there needs to be enough sample data in the source for the analysis to be reliable.

```sql
copy order_items from 's3://archive/orderitems.csv'
```

There is a notable difference between using the `ANALYZE COMPRESSION` command or having Redshift automatically apply compression during the `COPY` operation. The `ANALYZE COMPRESSION` command looks for minimum space usage and will very frequently recommend `ZStandard`. The `COPY` command on the other hand looks for the most time efficient encoding, which will most likely be `LZO`.