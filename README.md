# RASQL: Relation Algebra SQL

An idea originating from my research into relational algrebra and how it has been lost
to SQL and its dominance. I was originally curious as to what we might be losing out on,
and I also saw a lack of evolution in the traditional syntax used to query databases, so 
I sought to develop something influenced by pure functional language paradigms in the sense
of requiring proper thought and care in implementations, rather than throwing things together
in duct-tape fashion.

Plus I like learning new languages, and this was a good opportunity to do some more Zig.

Below is the syntax spec I have been aiming for:

## Relational Algebra Overview

One of the values of Relational Algebra-compliant databases is that in set theory, we cannot have
values of "NULL", nor can we have duplicate tuples in relations. This limitation forces a level
of database design and considerations that more easily allow for normalization to occur, and to 
reduce the amount - and possibility - of logical errors.

### Database Degrees
Attribute: column-level data
Tuple: row-level data

### Set Operators & Joins
In relational algebra we have different types of joins, many of which SQL users will be familiar with

#### Primary Set Operators
1. Union (+)
2. Difference (-)
3. Cartesian Product (*).

For Union and Difference, the relations involved must be `union-compatible`, meaning they must have the same
set of attributes.

For Cartesian Products, the involved relation must have `disjoint headers`, meaning they do not have a common attribute name.

#### Other Operators
1. Intersection (&)
2. Division (/)

Intersection - like Union and Difference - also requires the involved relations to be union-compatible.

#### Joins
1. Natural Join (><)
2. Theta/Equi Join ([])
3. Left and Right Semijoin (<<  >>)
4. Antijoin (!>)


### Primary RA Operations
Along with the common set operations, some extra ones are added to make working with a database easier.

1. `From (F:)`: what table to select
2. `Project (P:)`: columns to choose; similar to "SELECT" in SQL. Can use * to return all.
3. `Rename (R:)`: Optional - rename columns to help with later joins; similar to "AS" in SQL
4. `Select (S:)`: Optional - clauses to filter the dataset.
5. `Group (G:)`: Optional - columns to group aggregations by.
6. `Limit (L:)`: Optional - limit returned dataset size.


## Relations
Tables are called "Relations" as they commonly are in Relational Algebra.

Operations performed on Relations are done using the `RELATION` keyword.

### Creating Relations
To create a relation, we do something like this:

```
RELATION employee (
	u32: id PRIMARY
	str: name
	u32: department_id
	dt: start_date
	ts: ins_ts
);
```

The datatype comes first, followed by the column name, and any additional attributes.

#### Datatypes:

##### Integers:
i8, i16, i32, i64, u8, u16, u32, u64


##### Floats:
f32, f64

##### Strings:
str

##### Data & Time
dt (date) '2025-01-24'
ts (timestamp) '2025-01-024 07:23:45'


### Inserting into Relations
Inserts are done by using the `UNION` operator, followed by the desired tuples
```
RELATION employee + {
	(1, 'John', 1, '2024-01-01', '2024-01-01 02:20:54'),
	(2, 'Mike', 1, '2024-01-03', '2024-01-02 08:15:10'),
	(3, 'Jessica', 2, '2024-01-02', '2024-01-03 18:52:05'),
};
```

### Variables
As intermediary steps, we can define variables to later perform joins and filter data on.

```
E :=
	F: employee
	P: id, name, department_id
	S: *
S :=
	F: staff
	P: id, name, department_id
	R: name -> first_name
```

### Returning Data
To return data, we use the `RETURN` keyword.

We can return either a relation clause, or saved variables:

```
RETURN 
	F: employee
	S: *
;

RETURN E;
```
