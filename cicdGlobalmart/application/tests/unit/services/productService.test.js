const productService = require('../../services/productService');
const Product = require('../../models/Product');

// Mock the Product model
jest.mock('../../models/Product');

describe('Product Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getAllProducts', () => {
    test('should return all products', async () => {
      const mockProducts = [
        { id: 1, name: 'Product 1', price: 99.99 },
        { id: 2, name: 'Product 2', price: 149.99 }
      ];

      Product.findAll.mockResolvedValue(mockProducts);

      const result = await productService.getAllProducts();

      expect(Product.findAll).toHaveBeenCalledWith({
        where: {},
        include: [],
        order: [['createdAt', 'DESC']]
      });
      expect(result).toEqual(mockProducts);
    });

    test('should filter products by category', async () => {
      const mockProducts = [
        { id: 1, name: 'Electronics Product', category: 'Electronics' }
      ];

      Product.findAll.mockResolvedValue(mockProducts);

      const result = await productService.getAllProducts({ category: 'Electronics' });

      expect(Product.findAll).toHaveBeenCalledWith({
        where: { category: 'Electronics' },
        include: [],
        order: [['createdAt', 'DESC']]
      });
      expect(result).toEqual(mockProducts);
    });
  });

  describe('getProductById', () => {
    test('should return product by id', async () => {
      const mockProduct = { id: 1, name: 'Product 1', price: 99.99 };

      Product.findByPk.mockResolvedValue(mockProduct);

      const result = await productService.getProductById(1);

      expect(Product.findByPk).toHaveBeenCalledWith(1, {
        include: []
      });
      expect(result).toEqual(mockProduct);
    });

    test('should throw error if product not found', async () => {
      Product.findByPk.mockResolvedValue(null);

      await expect(productService.getProductById(999)).rejects.toThrow('Product not found');
    });
  });

  describe('createProduct', () => {
    test('should create a new product', async () => {
      const productData = {
        name: 'New Product',
        description: 'Product Description',
        price: 199.99,
        category: 'Electronics',
        stock: 50
      };

      const mockCreatedProduct = { id: 1, ...productData };

      Product.create.mockResolvedValue(mockCreatedProduct);

      const result = await productService.createProduct(productData);

      expect(Product.create).toHaveBeenCalledWith(productData);
      expect(result).toEqual(mockCreatedProduct);
    });

    test('should validate required fields', async () => {
      const invalidData = {
        name: '', // empty name
        price: -10 // negative price
      };

      await expect(productService.createProduct(invalidData)).rejects.toThrow();
    });
  });

  describe('updateProduct', () => {
    test('should update existing product', async () => {
      const productId = 1;
      const updateData = { name: 'Updated Product', price: 299.99 };
      const mockUpdatedProduct = { id: productId, ...updateData };

      Product.findByPk.mockResolvedValue({ id: productId, name: 'Old Product' });
      Product.update.mockResolvedValue([1]);
      Product.findByPk.mockResolvedValueOnce(mockUpdatedProduct);

      const result = await productService.updateProduct(productId, updateData);

      expect(Product.update).toHaveBeenCalledWith(updateData, {
        where: { id: productId }
      });
      expect(result).toEqual(mockUpdatedProduct);
    });

    test('should throw error if product not found', async () => {
      Product.findByPk.mockResolvedValue(null);

      await expect(productService.updateProduct(999, { name: 'Updated' })).rejects.toThrow('Product not found');
    });
  });

  describe('deleteProduct', () => {
    test('should delete existing product', async () => {
      const productId = 1;
      const mockProduct = { id: productId, name: 'Product to Delete' };

      Product.findByPk.mockResolvedValue(mockProduct);
      Product.destroy.mockResolvedValue(1);

      await productService.deleteProduct(productId);

      expect(Product.destroy).toHaveBeenCalledWith({
        where: { id: productId }
      });
    });

    test('should throw error if product not found', async () => {
      Product.findByPk.mockResolvedValue(null);

      await expect(productService.deleteProduct(999)).rejects.toThrow('Product not found');
    });
  });
});
