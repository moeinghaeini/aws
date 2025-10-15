const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const slowDown = require('express-slow-down');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true
}));

// Compression middleware
app.use(compression());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Speed limiting
const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000, // 15 minutes
  delayAfter: 50, // allow 50 requests per 15 minutes, then...
  delayMs: 500 // begin adding 500ms of delay per request above 50
});
app.use(speedLimiter);

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
    version: process.env.npm_package_version || '1.0.0',
    database: 'connected' // This would be checked against actual DB
  });
});

// API Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Repair Shop Management System API',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
    endpoints: {
      customers: '/api/customers',
      repairs: '/api/repairs',
      inventory: '/api/inventory',
      users: '/api/users',
      auth: '/api/auth'
    }
  });
});

// Customer routes
app.get('/api/customers', (req, res) => {
  const customers = [
    {
      id: 1,
      name: 'John Smith',
      email: 'john.smith@email.com',
      phone: '+1-555-0123',
      address: '123 Main St, Anytown, USA',
      createdAt: '2024-01-15T10:30:00Z',
      totalRepairs: 5,
      totalSpent: 1250.00
    },
    {
      id: 2,
      name: 'Sarah Johnson',
      email: 'sarah.j@email.com',
      phone: '+1-555-0456',
      address: '456 Oak Ave, Somewhere, USA',
      createdAt: '2024-01-20T14:15:00Z',
      totalRepairs: 3,
      totalSpent: 850.00
    },
    {
      id: 3,
      name: 'Mike Wilson',
      email: 'mike.wilson@email.com',
      phone: '+1-555-0789',
      address: '789 Pine Rd, Elsewhere, USA',
      createdAt: '2024-02-01T09:45:00Z',
      totalRepairs: 2,
      totalSpent: 450.00
    }
  ];
  
  res.json(customers);
});

app.get('/api/customers/:id', (req, res) => {
  const customerId = parseInt(req.params.id);
  const customer = {
    id: customerId,
    name: 'John Smith',
    email: 'john.smith@email.com',
    phone: '+1-555-0123',
    address: '123 Main St, Anytown, USA',
    createdAt: '2024-01-15T10:30:00Z',
    totalRepairs: 5,
    totalSpent: 1250.00,
    repairs: [
      {
        id: 1,
        description: 'Laptop screen replacement',
        status: 'completed',
        cost: 300.00,
        createdAt: '2024-01-15T10:30:00Z'
      },
      {
        id: 2,
        description: 'Keyboard repair',
        status: 'in_progress',
        cost: 150.00,
        createdAt: '2024-02-01T14:20:00Z'
      }
    ]
  };
  
  res.json(customer);
});

// Repair routes
app.get('/api/repairs', (req, res) => {
  const repairs = [
    {
      id: 1,
      customerId: 1,
      customerName: 'John Smith',
      description: 'Laptop screen replacement',
      status: 'completed',
      priority: 'medium',
      cost: 300.00,
      estimatedCompletion: '2024-01-20T00:00:00Z',
      actualCompletion: '2024-01-18T00:00:00Z',
      createdAt: '2024-01-15T10:30:00Z',
      notes: 'Screen replaced successfully, all tests passed'
    },
    {
      id: 2,
      customerId: 1,
      customerName: 'John Smith',
      description: 'Keyboard repair',
      status: 'in_progress',
      priority: 'low',
      cost: 150.00,
      estimatedCompletion: '2024-02-10T00:00:00Z',
      actualCompletion: null,
      createdAt: '2024-02-01T14:20:00Z',
      notes: 'Waiting for replacement keyboard to arrive'
    },
    {
      id: 3,
      customerId: 2,
      customerName: 'Sarah Johnson',
      description: 'Phone battery replacement',
      status: 'pending',
      priority: 'high',
      cost: 80.00,
      estimatedCompletion: '2024-02-15T00:00:00Z',
      actualCompletion: null,
      createdAt: '2024-02-10T11:15:00Z',
      notes: 'Customer reported phone not holding charge'
    }
  ];
  
  res.json(repairs);
});

app.get('/api/repairs/:id', (req, res) => {
  const repairId = parseInt(req.params.id);
  const repair = {
    id: repairId,
    customerId: 1,
    customerName: 'John Smith',
    description: 'Laptop screen replacement',
    status: 'completed',
    priority: 'medium',
    cost: 300.00,
    estimatedCompletion: '2024-01-20T00:00:00Z',
    actualCompletion: '2024-01-18T00:00:00Z',
    createdAt: '2024-01-15T10:30:00Z',
    notes: 'Screen replaced successfully, all tests passed',
    parts: [
      {
        id: 1,
        name: 'LCD Screen 15.6"',
        partNumber: 'LCD-156-001',
        cost: 200.00,
        quantity: 1
      },
      {
        id: 2,
        name: 'Screen Bezel',
        partNumber: 'BEZ-156-001',
        cost: 50.00,
        quantity: 1
      }
    ],
    labor: {
      hours: 2.0,
      rate: 25.00,
      total: 50.00
    }
  };
  
  res.json(repair);
});

// Inventory routes
app.get('/api/inventory', (req, res) => {
  const inventory = [
    {
      id: 1,
      name: 'LCD Screen 15.6"',
      partNumber: 'LCD-156-001',
      category: 'Screens',
      quantity: 5,
      minQuantity: 2,
      cost: 200.00,
      price: 250.00,
      supplier: 'TechParts Inc',
      lastRestocked: '2024-01-10T00:00:00Z'
    },
    {
      id: 2,
      name: 'Keyboard Assembly',
      partNumber: 'KB-001',
      category: 'Input Devices',
      quantity: 3,
      minQuantity: 1,
      cost: 80.00,
      price: 120.00,
      supplier: 'KeyTech Solutions',
      lastRestocked: '2024-01-25T00:00:00Z'
    },
    {
      id: 3,
      name: 'Battery Pack 5000mAh',
      partNumber: 'BAT-5000',
      category: 'Batteries',
      quantity: 8,
      minQuantity: 3,
      cost: 45.00,
      price: 65.00,
      supplier: 'PowerCell Corp',
      lastRestocked: '2024-02-05T00:00:00Z'
    }
  ];
  
  res.json(inventory);
});

// User routes
app.get('/api/users', (req, res) => {
  const users = [
    {
      id: 1,
      username: 'admin',
      email: 'admin@repairshop.com',
      role: 'admin',
      firstName: 'Admin',
      lastName: 'User',
      isActive: true,
      lastLogin: '2024-02-10T08:30:00Z'
    },
    {
      id: 2,
      username: 'technician1',
      email: 'tech1@repairshop.com',
      role: 'technician',
      firstName: 'John',
      lastName: 'Technician',
      isActive: true,
      lastLogin: '2024-02-10T09:15:00Z'
    }
  ];
  
  res.json(users);
});

// Auth routes
app.post('/api/auth/login', (req, res) => {
  const { username, password } = req.body;
  
  // Mock authentication - in real app, this would validate against database
  if (username === 'admin' && password === 'admin123') {
    const token = 'mock-jwt-token-' + Date.now();
    res.json({
      token,
      user: {
        id: 1,
        username: 'admin',
        email: 'admin@repairshop.com',
        role: 'admin',
        firstName: 'Admin',
        lastName: 'User'
      }
    });
  } else {
    res.status(401).json({ error: 'Invalid credentials' });
  }
});

app.post('/api/auth/logout', (req, res) => {
  res.json({ message: 'Logged out successfully' });
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
  console.log(`Repair Shop API server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

module.exports = app;
