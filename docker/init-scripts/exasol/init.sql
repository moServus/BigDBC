-- Demo schema for SQL SPA Explorer — Exasol
-- Run manually after container reaches healthy state (Exasol has no
-- docker-entrypoint-initdb.d mechanism). setup.ps1 executes this via exaplus.

CREATE SCHEMA IF NOT EXISTS demo;

CREATE TABLE IF NOT EXISTS demo.categories (
    id          DECIMAL(18, 0) IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(4000)
);

CREATE TABLE IF NOT EXISTS demo.products (
    id          DECIMAL(18, 0) IDENTITY PRIMARY KEY,
    category_id DECIMAL(18, 0),
    name        VARCHAR(200) NOT NULL,
    price       DECIMAL(10, 2) NOT NULL,
    stock       DECIMAL(10, 0) DEFAULT 0 NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id)
        REFERENCES demo.categories(id)
);

INSERT INTO demo.categories (name, description) VALUES ('Electronics', 'Gadgets and devices');
INSERT INTO demo.categories (name, description) VALUES ('Books',       'Printed and digital media');
INSERT INTO demo.categories (name, description) VALUES ('Clothing',    'Apparel and accessories');

INSERT INTO demo.products (category_id, name, price, stock) VALUES (1, 'Laptop',     999.99, 50);
INSERT INTO demo.products (category_id, name, price, stock) VALUES (1, 'Headphones', 149.99, 200);
INSERT INTO demo.products (category_id, name, price, stock) VALUES (2, 'Clean Code',  39.99, 100);
INSERT INTO demo.products (category_id, name, price, stock) VALUES (3, 'T-Shirt',     19.99, 500);

COMMIT;
