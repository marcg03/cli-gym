sed -i -e 's/^db_host = localhost$/db_host = db01.internal/' -e '/^#/!s/.*debug.*/# &/' app.conf
