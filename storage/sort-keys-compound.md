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