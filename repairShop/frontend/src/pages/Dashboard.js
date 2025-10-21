import React from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Paper,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  Chip
} from '@mui/material';
import {
  People,
  Build,
  Inventory,
  TrendingUp,
  Warning,
  CheckCircle
} from '@mui/icons-material';

const Dashboard = () => {
  const stats = [
    { title: 'Total Customers', value: '156', icon: <People />, color: '#1976d2' },
    { title: 'Active Repairs', value: '23', icon: <Build />, color: '#ff9800' },
    { title: 'Inventory Items', value: '89', icon: <Inventory />, color: '#4caf50' },
    { title: 'Monthly Revenue', value: '$12,450', icon: <TrendingUp />, color: '#9c27b0' }
  ];

  const recentRepairs = [
    { id: 1, customer: 'John Smith', description: 'Laptop screen replacement', status: 'completed', priority: 'medium' },
    { id: 2, customer: 'Sarah Johnson', description: 'Phone battery replacement', status: 'in_progress', priority: 'high' },
    { id: 3, customer: 'Mike Wilson', description: 'Keyboard repair', status: 'pending', priority: 'low' },
    { id: 4, customer: 'Lisa Brown', description: 'Tablet charging port', status: 'in_progress', priority: 'medium' }
  ];

  const lowStockItems = [
    { name: 'LCD Screen 15.6"', current: 2, minimum: 5 },
    { name: 'Battery Pack 5000mAh', current: 1, minimum: 3 },
    { name: 'Charging Cable USB-C', current: 0, minimum: 10 }
  ];

  const getStatusColor = (status) => {
    switch (status) {
      case 'completed': return 'success';
      case 'in_progress': return 'warning';
      case 'pending': return 'default';
      default: return 'default';
    }
  };

  const getPriorityColor = (priority) => {
    switch (priority) {
      case 'high': return 'error';
      case 'medium': return 'warning';
      case 'low': return 'success';
      default: return 'default';
    }
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Dashboard
      </Typography>
      
      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        {stats.map((stat, index) => (
          <Grid item xs={12} sm={6} md={3} key={index}>
            <Card>
              <CardContent>
                <Box display="flex" alignItems="center">
                  <Box
                    sx={{
                      backgroundColor: stat.color,
                      color: 'white',
                      borderRadius: '50%',
                      p: 1,
                      mr: 2
                    }}
                  >
                    {stat.icon}
                  </Box>
                  <Box>
                    <Typography variant="h4" component="div">
                      {stat.value}
                    </Typography>
                    <Typography color="text.secondary">
                      {stat.title}
                    </Typography>
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      <Grid container spacing={3}>
        {/* Recent Repairs */}
        <Grid item xs={12} md={6}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Recent Repairs
            </Typography>
            <List>
              {recentRepairs.map((repair) => (
                <ListItem key={repair.id} divider>
                  <ListItemIcon>
                    <Build />
                  </ListItemIcon>
                  <ListItemText
                    primary={repair.description}
                    secondary={`Customer: ${repair.customer}`}
                  />
                  <Box sx={{ ml: 2 }}>
                    <Chip
                      label={repair.status}
                      color={getStatusColor(repair.status)}
                      size="small"
                      sx={{ mr: 1 }}
                    />
                    <Chip
                      label={repair.priority}
                      color={getPriorityColor(repair.priority)}
                      size="small"
                    />
                  </Box>
                </ListItem>
              ))}
            </List>
          </Paper>
        </Grid>

        {/* Low Stock Alert */}
        <Grid item xs={12} md={6}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Low Stock Alert
            </Typography>
            <List>
              {lowStockItems.map((item, index) => (
                <ListItem key={index} divider>
                  <ListItemIcon>
                    <Warning color="error" />
                  </ListItemIcon>
                  <ListItemText
                    primary={item.name}
                    secondary={`Current: ${item.current} | Minimum: ${item.minimum}`}
                  />
                  <Chip
                    label="Reorder"
                    color="error"
                    size="small"
                  />
                </ListItem>
              ))}
            </List>
          </Paper>
        </Grid>
      </Grid>

      {/* Quick Actions */}
      <Paper sx={{ p: 2, mt: 3 }}>
        <Typography variant="h6" gutterBottom>
          Quick Actions
        </Typography>
        <Grid container spacing={2}>
          <Grid item xs={12} sm={6} md={3}>
            <Card sx={{ cursor: 'pointer', '&:hover': { boxShadow: 3 } }}>
              <CardContent sx={{ textAlign: 'center' }}>
                <People sx={{ fontSize: 40, color: '#1976d2', mb: 1 }} />
                <Typography variant="h6">Add Customer</Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Card sx={{ cursor: 'pointer', '&:hover': { boxShadow: 3 } }}>
              <CardContent sx={{ textAlign: 'center' }}>
                <Build sx={{ fontSize: 40, color: '#ff9800', mb: 1 }} />
                <Typography variant="h6">New Repair</Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Card sx={{ cursor: 'pointer', '&:hover': { boxShadow: 3 } }}>
              <CardContent sx={{ textAlign: 'center' }}>
                <Inventory sx={{ fontSize: 40, color: '#4caf50', mb: 1 }} />
                <Typography variant="h6">Add Inventory</Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <Card sx={{ cursor: 'pointer', '&:hover': { boxShadow: 3 } }}>
              <CardContent sx={{ textAlign: 'center' }}>
                <CheckCircle sx={{ fontSize: 40, color: '#9c27b0', mb: 1 }} />
                <Typography variant="h6">Complete Repair</Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      </Paper>
    </Box>
  );
};

export default Dashboard;
