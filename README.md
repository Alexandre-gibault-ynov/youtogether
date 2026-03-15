# youtogether
YouTogether: watch YouTube videos together.

# Prerequisite

To run the project on local environment:
1. Clone this repository
2. go to the backend repository:
   ```bash
   cd backend/
   ```
3. Install [PostgreSQL](https://www.postgresql.org/)
4. Create the database:
   ```bash
   psql -U <user> -c "CREATE DATABASE youtogether;"
   ```
5. Run this command:
   ```bash
   psql -U <user> -d youtogether -f init.sql
   ```
6. See the [frontend README](https://github.com/Alexandre-gibault-ynov/youtogether/blob/main/frontend/README.md) to start the frontend
7. See the [backend README](https://github.com/Alexandre-gibault-ynov/youtogether/tree/main/backend/sql) to start the backend
