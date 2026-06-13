-- Demo schema for SQL SPA Explorer — Oracle Free (FREEPDB1)
-- gvenzl/oracle-free runs this as APP_USER ("explorer") in FREEPDB1
-- via /container-entrypoint-initdb.d/

CREATE TABLE categories (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR2(100) NOT NULL,
    description VARCHAR2(4000)
);

CREATE TABLE products (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id NUMBER REFERENCES categories(id),
    name        VARCHAR2(200) NOT NULL,
    price       NUMBER(10, 2) NOT NULL,
    stock       NUMBER DEFAULT 0 NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO categories (name, description) VALUES ('Electronics', 'Gadgets and devices');
INSERT INTO categories (name, description) VALUES ('Books',       'Printed and digital media');
INSERT INTO categories (name, description) VALUES ('Clothing',    'Apparel and accessories');

INSERT INTO products (category_id, name, price, stock) VALUES (1, 'Laptop',     999.99, 50);
INSERT INTO products (category_id, name, price, stock) VALUES (1, 'Headphones', 149.99, 200);
INSERT INTO products (category_id, name, price, stock) VALUES (2, 'Clean Code',  39.99, 100);
INSERT INTO products (category_id, name, price, stock) VALUES (3, 'T-Shirt',     19.99, 500);

COMMIT;
