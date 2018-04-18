# Appending

Immutable data makes shoveling data around so much easier in general. If the source database contains concepts like `clicks`, `events` or `transactions`, we can read the rows since our last checkpoint and write those to a file. To add the data to the destination Redshift database, it's just a single `COPY` command.

When you're dealing with temporal data, such as `clicks` or `transactions`, chances are high the `timestamp` column is defined as the sort key. When the source data is also sorted by `timestamp`, Redshift won't need to change any blocks, resulting in an extremely efficient copy operation.