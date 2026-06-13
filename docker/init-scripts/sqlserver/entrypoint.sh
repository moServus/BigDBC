#!/bin/bash
# SQL Server has no docker-entrypoint-initdb.d mechanism.
# This script starts sqlservr in the background, waits until it accepts
# connections, runs the init SQL via sqlcmd, then hands control back to
# the foreground sqlservr process.

set -e

/opt/mssql/bin/sqlservr &
MSSQL_PID=$!

echo "[entrypoint] Waiting for SQL Server to accept connections..."
for i in $(seq 1 60); do
    /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" \
        -Q "SELECT 1" -C -l 3 \
        > /dev/null 2>&1 && break
    sleep 2
done

echo "[entrypoint] Running init script..."
/opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" \
    -i /docker-init/init.sql -C

echo "[entrypoint] Init complete."
wait $MSSQL_PID
