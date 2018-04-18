# Nodes

A Redshift cluster contains one or multiple nodes. Each cluster contains exactly one leader and one or more compute nodes. If you have a cluster with only one node in it, this node assumes both roles: leader and compute.

As a client application, the composition of a cluster is transparent to you. You will always only talk to the leader node. The leader node is responsible for the intake and coordination of queries.  When the leader node receives a query, it first parses the query and turns it into an optimized execution plan. These steps will then be compiled into code and distributed to the compute nodes. When the compute nodes return intermediate result sets, the leader merges these together and replies to the client application.

```txt
              Client
                |
                |
              Leader
      ---------------------
    /           |          \
 | Compute | Compute | Compute |

```