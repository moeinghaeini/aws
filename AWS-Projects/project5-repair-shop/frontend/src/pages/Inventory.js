import React from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  Chip,
  Button,
  IconButton,
  LinearProgress
} from '@mui/material';
import {
  Add,
  Edit,
  Delete,
  Warning,
  CheckCircle,
  Inventory as InventoryIcon
} from '@mui/icons-material';

const Inventory = () => {
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
      lastRestocked: '2024-01-10T00:00:00Z',
      status: 'good'
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
      lastRestocked: '2024-01-25T00:00:00Z',
      status: 'good'
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
      lastRestocked: '2024-02-05T00:00:00Z',
      status: 'good'
    },
    {
      id: 4,
      name: 'Charging Cable USB-C',
      partNumber: 'CBL-USB-C-001',
      category: 'Cables',
      quantity: 2,
      minQuantity: 10,
      cost: 15.00,
      price: 25.00,
      supplier: 'CableTech Ltd',
      lastRestocked: '2024-01-15T00:00:00Z',
      status: 'low'
    },
    {
      id: 5,
      name: 'Touch Screen Digitizer',
      partNumber: 'DIG-7-001',
      category: 'Screens',
      quantity: 1,
      minQuantity: 3,
      cost: 120.00,
      price: 180.00,
      supplier: 'ScreenTech Pro',
      lastRestocked: '2024-01-20T00:00:00Z',
      status: 'critical'
    },
    {
      id: 6,
      name: 'Power Adapter 65W',
      partNumber: 'PA-65W-001',
      category: 'Power',
      quantity: 12,
      minQuantity: 5,
      cost: 35.00,
      price: 55.00,
      supplier: 'PowerTech Inc',
      lastRestocked: '2024-02-08T00:00:00Z',
      status: 'good'
    }
  ];

  const getStatusColor = (status) => {
    switch (status) {
      case 'good': return 'success';
      case 'low': return 'warning';
      case 'critical': return 'error';
      default: return 'default';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'good': return <CheckCircle />;
      case 'low': return <Warning />;
      case 'critical': return <Warning />;
      default: return <InventoryIcon />;
    }
  };

  const getStockPercentage = (quantity, minQuantity) => {
    return Math.min((quantity / (minQuantity * 2)) * 100, 100);
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString();
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4">
          Inventory
        </Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          sx={{ ml: 2 }}
        >
          Add Item
        </Button>
      </Box>

      <Grid container spacing={3}>
        {inventory.map((item) => (
          <Grid item xs={12} sm={6} md={4} key={item.id}>
            <Card 
              className={`inventory-item ${
                item.status === 'critical' ? 'low-stock' : 
                item.status === 'low' ? 'medium-stock' : 'good-stock'
              }`}
            >
              <CardContent>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                  <Typography variant="h6" component="div">
                    {item.name}
                  </Typography>
                  <Chip
                    icon={getStatusIcon(item.status)}
                    label={item.status}
                    color={getStatusColor(item.status)}
                    size="small"
                  />
                </Box>

                <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                  Part #: {item.partNumber}
                </Typography>
                
                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                  Category: {item.category}
                </Typography>

                <Box sx={{ mb: 2 }}>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                    <Typography variant="body2" color="text.secondary">
                      Stock Level
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      {item.quantity} / {item.minQuantity} min
                    </Typography>
                  </Box>
                  <LinearProgress
                    variant="determinate"
                    value={getStockPercentage(item.quantity, item.minQuantity)}
                    sx={{ 
                      height: 8, 
                      borderRadius: 4,
                      backgroundColor: item.status === 'critical' ? '#ffebee' : 
                                     item.status === 'low' ? '#fff8e1' : '#e8f5e8'
                    }}
                  />
                </Box>

                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      Cost
                    </Typography>
                    <Typography variant="body1" color="text.primary">
                      ${item.cost.toFixed(2)}
                    </Typography>
                  </Box>
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      Price
                    </Typography>
                    <Typography variant="body1" color="primary.main">
                      ${item.price.toFixed(2)}
                    </Typography>
                  </Box>
                </Box>

                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                  Supplier: {item.supplier}
                </Typography>

                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                  Last Restocked: {formatDate(item.lastRestocked)}
                </Typography>

                <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                  <Button
                    variant="outlined"
                    size="small"
                    startIcon={<Edit />}
                  >
                    Edit
                  </Button>
                  <Button
                    variant="outlined"
                    size="small"
                    color="primary"
                  >
                    Restock
                  </Button>
                  <IconButton
                    size="small"
                    color="error"
                  >
                    <Delete />
                  </IconButton>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {/* Summary Cards */}
      <Grid container spacing={3} sx={{ mt: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                <CheckCircle sx={{ fontSize: 40, color: 'success.main', mr: 2 }} />
                <Box>
                  <Typography variant="h4" component="div">
                    {inventory.filter(item => item.status === 'good').length}
                  </Typography>
                  <Typography color="text.secondary">
                    Good Stock
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                <Warning sx={{ fontSize: 40, color: 'warning.main', mr: 2 }} />
                <Box>
                  <Typography variant="h4" component="div">
                    {inventory.filter(item => item.status === 'low').length}
                  </Typography>
                  <Typography color="text.secondary">
                    Low Stock
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                <Warning sx={{ fontSize: 40, color: 'error.main', mr: 2 }} />
                <Box>
                  <Typography variant="h4" component="div">
                    {inventory.filter(item => item.status === 'critical').length}
                  </Typography>
                  <Typography color="text.secondary">
                    Critical Stock
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                <InventoryIcon sx={{ fontSize: 40, color: 'primary.main', mr: 2 }} />
                <Box>
                  <Typography variant="h4" component="div">
                    {inventory.length}
                  </Typography>
                  <Typography color="text.secondary">
                    Total Items
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Inventory;
