# Copy from S3

When you're copying data from a relational database into Redshift, the best option is to use file based imports using Amazon S3. You read the data from the source database, write it to a file, compress the file and upload it to your private S3 bucket attaching a bit of useful meta data like file type, source etc. On the receiving end, you subscribe to an S3 event and import the file. Ideally, you persist the path of the uploaded file with its meta data to a small database and checkpoint the files you've imported. Having this secondary index into your private S3 bucket together with a checkpoint allows imports to pick up where they left off and to import the whole lot again later on.

```sql
copy order_items
from 's3://webshop-archive/orderitems/v1/2017/12/21/log-1-5008441.zip'
iam_role 'arn:aws:iam:123456:role/dwimport'
```