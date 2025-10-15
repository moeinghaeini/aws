const request = require('supertest');
const app = require('../server');

describe('GlobalMart E-Commerce API', () => {
  describe('GET /', () => {
    it('should return welcome message', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);
      
      expect(response.body.message).toBe('Welcome to GlobalMart E-Commerce Platform');
      expect(response.body.version).toBe('1.0.0');
    });
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);
      
      expect(response.body.status).toBe('healthy');
      expect(response.body.timestamp).toBeDefined();
      expect(response.body.uptime).toBeDefined();
    });
  });

  describe('GET /api/products', () => {
    it('should return list of products', async () => {
      const response = await request(app)
        .get('/api/products')
        .expect(200);
      
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
      expect(response.body[0]).toHaveProperty('id');
      expect(response.body[0]).toHaveProperty('name');
      expect(response.body[0]).toHaveProperty('price');
    });
  });

  describe('GET /api/products/:id', () => {
    it('should return specific product', async () => {
      const response = await request(app)
        .get('/api/products/1')
        .expect(200);
      
      expect(response.body.id).toBe(1);
      expect(response.body.name).toBe('Wireless Headphones');
      expect(response.body.price).toBe(99.99);
    });

    it('should return 404 for non-existent product', async () => {
      const response = await request(app)
        .get('/api/products/999')
        .expect(404);
      
      expect(response.body.error).toBe('Product not found');
    });
  });

  describe('POST /api/orders', () => {
    it('should create a new order', async () => {
      const orderData = {
        items: [
          { id: 1, name: 'Wireless Headphones', price: 99.99, quantity: 1 }
        ],
        customerInfo: {
          name: 'John Doe',
          email: 'john@example.com'
        }
      };

      const response = await request(app)
        .post('/api/orders')
        .send(orderData)
        .expect(201);
      
      expect(response.body.id).toBeDefined();
      expect(response.body.status).toBe('pending');
      expect(response.body.total).toBe(99.99);
    });

    it('should return 400 for invalid order', async () => {
      const response = await request(app)
        .post('/api/orders')
        .send({})
        .expect(400);
      
      expect(response.body.error).toBe('Order items are required');
    });
  });

  describe('GET /api/categories', () => {
    it('should return list of categories', async () => {
      const response = await request(app)
        .get('/api/categories')
        .expect(200);
      
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
      expect(response.body[0]).toHaveProperty('id');
      expect(response.body[0]).toHaveProperty('name');
      expect(response.body[0]).toHaveProperty('count');
    });
  });
});
