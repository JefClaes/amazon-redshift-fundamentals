# Durability and fault tolerance

So far we've seen that Redshift uses a cluster of nodes as a means to distribute data and to parallelize computation. In general, with each component added to a cluster of machines, the odds of failure increase. Each failure has the potential to bring the whole system to a halt, or even worse, to lose data.

Redshift has two effective measures in place to prevent data loss, ensuring durability. When you load data, Redshift synchronously replicates this data to other disks in the cluster. Next to that, data is also automatically replicated to S3 to provide continuous and incremental backups. Note that synchronous replication is not supported in a single node cluster - there's nowhere to replicate to.

A Redshift cluster is actively monitored for disk and node failures. In case of a disk failing on a single node, the node automatically starts using an in-cluster replica of the failing drive, while Redshift starts preparing a new healthy drive. When a node dies, Redshift stops serving queries until the cluster is healthy again. It will automatically provision and configure a new node, resuming operations when data is consistent again.

In theory, you can expect an unhealthy cluster to heal itself - without any intervention. Depending on the gravity of the failure, some downtime is to be expected. Redshift favors consistency over availability.