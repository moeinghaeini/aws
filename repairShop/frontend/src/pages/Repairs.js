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
  Visibility,
  Build,
  Person,
  Schedule
} from '@mui/icons-material';

const Repairs = () => {
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
      progress: 100
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
      progress: 60
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
      progress: 0
    },
    {
      id: 4,
      customerId: 3,
      customerName: 'Mike Wilson',
      description: 'Tablet charging port repair',
      status: 'in_progress',
      priority: 'medium',
      cost: 120.00,
      estimatedCompletion: '2024-02-20T00:00:00Z',
      actualCompletion: null,
      createdAt: '2024-02-12T09:30:00Z',
      progress: 30
    }
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

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString();
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4">
          Repairs
        </Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          sx={{ ml: 2 }}
        >
          New Repair
        </Button>
      </Box>

      <Grid container spacing={3}>
        {repairs.map((repair) => (
          <Grid item xs={12} sm={6} md={4} key={repair.id}>
            <Card className="repair-card">
              <CardContent>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 2 }}>
                  <Typography variant="h6" component="div">
                    #{repair.id}
                  </Typography>
                  <Box>
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
                </Box>

                <Typography variant="body1" sx={{ mb: 2, fontWeight: 'medium' }}>
                  {repair.description}
                </Typography>

                <Box sx={{ mb: 2 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    <Person sx={{ fontSize: 16, mr: 1, color: 'text.secondary' }} />
                    <Typography variant="body2" color="text.secondary">
                      {repair.customerName}
                    </Typography>
                  </Box>
                  
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    <Schedule sx={{ fontSize: 16, mr: 1, color: 'text.secondary' }} />
                    <Typography variant="body2" color="text.secondary">
                      Created: {formatDate(repair.createdAt)}
                    </Typography>
                  </Box>
                  
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    <Build sx={{ fontSize: 16, mr: 1, color: 'text.secondary' }} />
                    <Typography variant="body2" color="text.secondary">
                      Est. Completion: {formatDate(repair.estimatedCompletion)}
                    </Typography>
                  </Box>
                </Box>

                {repair.status === 'in_progress' && (
                  <Box sx={{ mb: 2 }}>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                      Progress: {repair.progress}%
                    </Typography>
                    <LinearProgress
                      variant="determinate"
                      value={repair.progress}
                      sx={{ height: 8, borderRadius: 4 }}
                    />
                  </Box>
                )}

                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                  <Typography variant="h6" color="primary">
                    ${repair.cost.toFixed(2)}
                  </Typography>
                  {repair.actualCompletion && (
                    <Typography variant="body2" color="text.secondary">
                      Completed: {formatDate(repair.actualCompletion)}
                    </Typography>
                  )}
                </Box>

                <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                  <Button
                    variant="outlined"
                    size="small"
                    startIcon={<Visibility />}
                  >
                    View
                  </Button>
                  <Button
                    variant="outlined"
                    size="small"
                    startIcon={<Edit />}
                  >
                    Edit
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
    </Box>
  );
};

export default Repairs;
