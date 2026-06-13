// Demo schema for SQL SPA Explorer — MongoDB
// Runs automatically on first container start via /docker-entrypoint-initdb.d/
// MONGO_INITDB_DATABASE env var switches to the target DB before this script runs.

db.createCollection('categories');
db.createCollection('products');

db.categories.insertMany([
    { _id: 1, name: 'Electronics', description: 'Gadgets and devices' },
    { _id: 2, name: 'Books',       description: 'Printed and digital media' },
    { _id: 3, name: 'Clothing',    description: 'Apparel and accessories' }
]);

db.products.insertMany([
    { _id: 1, categoryId: 1, name: 'Laptop',     price: 999.99, stock: 50,  createdAt: new Date() },
    { _id: 2, categoryId: 1, name: 'Headphones', price: 149.99, stock: 200, createdAt: new Date() },
    { _id: 3, categoryId: 2, name: 'Clean Code', price: 39.99,  stock: 100, createdAt: new Date() },
    { _id: 4, categoryId: 3, name: 'T-Shirt',    price: 19.99,  stock: 500, createdAt: new Date() }
]);

db.products.createIndex({ categoryId: 1 });
db.products.createIndex({ name: 'text' });
