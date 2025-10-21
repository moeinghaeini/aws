const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Logging
app.use(morgan('combined'));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: process.env.npm_package_version || '1.0.0'
  });
});

// API Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to GlobalMart E-Commerce Platform',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// Products API
app.get('/api/products', (req, res) => {
  const products = [
    {
      id: 1,
      name: 'Wireless Headphones',
      price: 99.99,
      category: 'Electronics',
      description: 'High-quality wireless headphones with noise cancellation',
      image: '/images/headphones.jpg',
      stock: 50
    },
    {
      id: 2,
      name: 'Smart Watch',
      price: 199.99,
      category: 'Electronics',
      description: 'Advanced smartwatch with health monitoring',
      image: '/images/smartwatch.jpg',
      stock: 25
    },
    {
      id: 3,
      name: 'Laptop Backpack',
      price: 49.99,
      category: 'Accessories',
      description: 'Durable laptop backpack with multiple compartments',
      image: '/images/backpack.jpg',
      stock: 100
    },
    {
      id: 4,
      name: 'Coffee Maker',
      price: 79.99,
      category: 'Home & Kitchen',
      description: 'Programmable coffee maker with timer',
      image: '/images/coffee-maker.jpg',
      stock: 30
    }
  ];
  
  res.json(products);
});

app.get('/api/products/:id', (req, res) => {
  const productId = parseInt(req.params.id);
  const products = [
    {
      id: 1,
      name: 'Wireless Headphones',
      price: 99.99,
      category: 'Electronics',
      description: 'High-quality wireless headphones with noise cancellation',
      image: '/images/headphones.jpg',
      stock: 50,
      reviews: [
        { id: 1, rating: 5, comment: 'Excellent sound quality!' },
        { id: 2, rating: 4, comment: 'Great value for money' }
      ]
    },
    {
      id: 2,
      name: 'Smart Watch',
      price: 199.99,
      category: 'Electronics',
      description: 'Advanced smartwatch with health monitoring',
      image: '/images/smartwatch.jpg',
      stock: 25,
      reviews: [
        { id: 1, rating: 5, comment: 'Love the health features!' }
      ]
    }
  ];
  
  const product = products.find(p => p.id === productId);
  if (!product) {
    return res.status(404).json({ error: 'Product not found' });
  }
  
  res.json(product);
});

// Orders API
app.post('/api/orders', (req, res) => {
  const { items, customerInfo } = req.body;
  
  if (!items || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'Order items are required' });
  }
  
  const order = {
    id: Date.now(),
    items,
    customerInfo,
    status: 'pending',
    total: items.reduce((sum, item) => sum + (item.price * item.quantity), 0),
    createdAt: new Date().toISOString()
  };
  
  res.status(201).json(order);
});

// Categories API
app.get('/api/categories', (req, res) => {
  const categories = [
    { id: 1, name: 'Electronics', count: 2 },
    { id: 2, name: 'Accessories', count: 1 },
    { id: 3, name: 'Home & Kitchen', count: 1 }
  ];
  
  res.json(categories);
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Start server
app.listen(PORT, () => {
  console.log(`GlobalMart server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

module.exports = app;
