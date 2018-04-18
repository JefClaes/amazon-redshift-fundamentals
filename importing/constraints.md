# Constraints

As you've already noticed in the examples used in the previous chapters, defining the schema of a table in Redshift is not much different than it would be any other relational database. If you're used to other relational databases and have always been disciplined about defining constraints as part of your schema, you might be up for a surprise.

Although Redshift allows you to define foreign keys and unique constraints, they are not enforced when modifying data. Can you imagine how expensive a load operation would be in a distributed database like Redshift? Each load operation would require all the slices to freeze time and to talk to one another before allowing a write to happen.

This doesn't mean that you shouldn't define constraints though. Redshift makes use of the schema metadata to optimize query plans.