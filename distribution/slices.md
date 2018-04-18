# Slices

Redshift even divides the system up into more little computation units. Each compute node is chopped into slices. Each slice is allocated a portion of the machine's disk, memory and CPU. Workloads are then distributed over these slices, having even more isolated individual units working in parallel to come up with results fast.

```txt
            Client
              |
              |
            Leader
        -------------
       /       |      \
| Compute | Compute | Compute |
| ------- | ------- | --------|
| Slice 0 | Slice 2 | Slice 4 |
| Slice 1 | Slice 3 | Slice 5 |

```

The number of nodes and slices assigned to your cluster, can be found in the `stv_slices` table.

```sql
select node, slice
from stv_slices;
```

| node | slice |
| ---- | ----- |
| 0    | 0     |
| 0    | 1     |
| 1    | 2     |
| 1    | 3     |

Inspecting the result, you can see I'm using a small cluster with 2 nodes that only contain 2 slices per node.
