-- Demo schema for SQL SPA Explorer — PostgreSQL
-- Runs automatically on first container start via /docker-entrypoint-initdb.d/

CREATE TABLE IF NOT EXISTS categories (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS products (
    id          SERIAL PRIMARY KEY,
    category_id INT REFERENCES categories(id),
    name        VARCHAR(200) NOT NULL,
    price       NUMERIC(10, 2) NOT NULL,
    stock       INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO categories (name, description) VALUES
    ('Electronics', 'Gadgets and devices'),
    ('Books',       'Printed and digital media'),
    ('Clothing',    'Apparel and accessories');

INSERT INTO products (category_id, name, price, stock) VALUES
    (1, 'Laptop',      999.99, 50),
    (1, 'Headphones',  149.99, 200),
    (2, 'Clean Code',   39.99, 100),
    (3, 'T-Shirt',      19.99, 500);
