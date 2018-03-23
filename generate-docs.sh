f1="./src/jennifer.cr "
f2="./src/jennifer/adapter/mysql.cr " # for mysql
f3="./src/jennifer/adapter/postgres.cr " # for postgres
f4="./src/jennifer/model/authentication.cr "

echo $f1$f2$f3$f4 | xargs crystal doc -odoc
