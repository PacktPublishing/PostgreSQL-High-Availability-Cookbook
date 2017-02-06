# PostgreSQL High Availability Cookbook
This is the code repository for [PostgreSQL High Availability Cookbook](https://www.packtpub.com/big-data-and-business-intelligence/postgresql-high-availability-cookbook-second-edition?utm_source=github&utm_medium=repository&utm_content=9781787125537), published by Packt. It contains all the supporting project files necessary to work through the book from start to finish.
## Instructions and Navigations
All of the code is organized into folders. Each folder starts with a number followed by the application name. For example, Chapter 3.


The code will look like the following:
          
          COPY (
                  SELECT '"' || rolname || '" "' ||
                  coalesce(rolpassword, '') || '"'
                    FROM pg_authid
            )
            TO '/etc/pgbouncer/userlist.txt';

### Software requirements:
This book concentrates on UNIX systems with a focus on Linux in particular. Such servers
have become increasingly popular for hosting databases for companies large and small. As
such, we highly recommend you have a virtual machine or development system running a
recent copy of Debian, Ubuntu, Red Hat Enterprise Linux or a variant such as CentOS or
Scientific Linux.

You will also need a copy of PostgreSQL. If your chosen Linux distribution isn't keeping the
included PostgreSQL packages sufficiently up to date, the PostgreSQL website maintains
binaries for most popular distributions. You can find these at the following URL:
h t t p s ://w w w . p o s t g r e s q l . o r g /d o w n l o a d /
Users of Red Hat Enterprise Linux and its variants should refer to the following URL to add
the official PostgreSQL YUM repository to important database systems:
h t t p s ://y u m . p o s t g r e s q l . o r g /r e p o p a c k a g e s . p h p
Users of Debian, Ubuntu, Mint, and other related Linux systems should refer to the
PostgreSQL APT wiki page at this URL instead:
h t t p s ://w i k i . p o s t g r e s q l . o r g /w i k i /A p t
Be sure to include any “contrib” packages in your installation. They include helpful utilities
and database extensions we will use in some recipes.
