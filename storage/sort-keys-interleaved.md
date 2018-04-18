# Interleaved

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