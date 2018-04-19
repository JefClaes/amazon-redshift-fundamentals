# Workload Management

A Redshift cluster has finite resources, making workload and queue management a crucial component of the execution engine. After Redshift has computed a query plan, the plan gets queued for execution. The queue puts an upper bound parallelism, reducing contention of the cluster's resources. Each queue has a reserved amount of memory assigned to it with a limited amount of slots available that can execute queries. Once a query is executed, the slot is released and the next query in line starts its execution.

In the default configuration, Redshift uses a single queue with only 5 slots. For a lot of workloads, the default configuration will do just fine for a good while. Especially when you show some mechanical sympathy by coordinating ETL jobs and caching of reads on top. But let's say you don't implement any lite infrastructure to support coordination and caching. Big loads are happening throughout the day, while you have a small army of concurrent users, hungry for fresh dashboard widgets and reports. It's not too hard to imagine one of those smaller queries getting stuck in the queue waiting for a slot, behind a batch of slow imports.

This is where Workload Management or `WLM` in short comes into play. With `WLM` you can tweak how Redshift makes use of its resources when executing queries. `WLM` allows you to create custom queues, configure which queries are routed to them and tune them for specific types of workloads. Per queue you can set the concurrency (number of available slots) and reserve a percentage of the memory. The memory that's assigned to a queue is assigned to each slot of the queue evenly.

In the use case of having big loads, small and big queries contending for resources, we could benefit from creating a queue that has 30% memory assigned to it, with only one slot available, reserved for copy operations. Another queue could be assigned 35% of the memory, with two slots available, used to generate those large reports. We only assign it two slots, because we know these queries are memory hungry and we don't want these queries to spill onto disk, but do as much of their work in-memory as possible. The default queue can't be removed and will be used for the remaining queries. Since these queries are fast, only querying a small subset of the data, we change the concurrency level to 12.

Routing of queries to queues can be configured in the AWS console per queue. The first option is to use `user groups` or `query groups`.

You can create a `user group` and assign it a list of database users.

```sql
create group reporting with backoffice;
```

Or you can set a `query group`, which is basically not much more than a label you set when executing a query.

```sql
set query_group to etl;

copy order_items from 's3://...'
```

There's also the option to make use of a small rules engine that can use predicates such as `Return row count`, `CPU usage` etc to decide on what queue a query is routed to. Use the S3 console to configure this.

You can stitch the `stv_wlm_*` system tables together to get an overview of the configured queues, their properties and the queries they're executing.

```sql
set enable_result_cache_for_session to off;

select
  (state.service_class-5)     as queue,
  trim(class.condition)       as description,
  config.num_query_tasks      as slots,
  config.query_working_mem    as memory_per_slot,
  config.max_execution_time   as timeout,
  state.num_queued_queries    as waiting,
  state.num_executing_queries as executing,
  state.num_executed_queries  as executed
from
  stv_wlm_classification_config as class,
  stv_wlm_service_class_config  as config,
  stv_wlm_service_class_state   as state
where
  class.action_service_class = config.service_class and
  class.action_service_class = state.service_class and
  config.service_class > 4;
```

| queue | description  | slots | memory_per_slot | timeout | waiting | executing | executed |
| ----- | -------------| ----- | --------------- | ------- | ------- | --------- | -------- |
| 0     | (super use.. | 1     | 476             | 0       | 0       | 0         | 0        |
| 1     | (query:any)  | 12    | 447             | 0       | 0       | 3         | 1511     |

This results shows that there are two queues in the system. The Redshift super user queue with one slot and 476MB of memory with no queries in queue. The second one is the default queue that has been configured to have 12 slots with 447MB of memory per slot. No queries are waiting to be executed, while there are 3 executing.

Another query on the `stv_wlm_query_state` table reveals which queries have been assigned to which queue and what their state is.

```sql
select
  query                as query,
  (service_class-5)    as queue,
  trim(wlm_start_time) as started_at,
  trim(state)          as state
from stv_wlm_query_state;

select *
from stl_query
where query = 739562;
```

| query  | queue  | started_at | state   |
| ------ | ------ | ---------  | ------- |
| 739590 | 1      | ..         | running |
| 739562 | 1      | ..         | running |
| 739592 | 1      | ..         | running |

Configuring your own queues can be a bit intimidating. A feature that can introduce a quick win - without requiring you to have a deep understanding of `WLM` and each query that runs on your cluster, is `Short Query Acceleration`. Enabling this flag in the console, Redshift creates a dedicated queue to run short queries, allowing queries to bypass slow queries or ETL jobs. It will then use machine learning to analyze your queries, predict their execution time and classify them accordingly. The longer `SQA` is enabled, the more it can learn, the better its predictions will be.