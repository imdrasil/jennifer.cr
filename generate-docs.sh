f1="./src/jennifer.cr "
f2="./src/jennifer/adapter/mysql.cr " # for mysql
f3="./src/jennifer/adapter/postgres.cr " # for postgres

echo $f1$f2$f3 | xargs crystal doc
