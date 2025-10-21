import React from 'react';
import { Card, Row, Col, ProgressBar, Badge } from 'react-bootstrap';

const Dashboard = () => {
  const stats = [
    { title: "Courses Enrolled", value: "12", color: "primary" },
    { title: "Completed", value: "8", color: "success" },
    { title: "In Progress", value: "4", color: "warning" },
    { title: "Certificates", value: "6", color: "info" }
  ];

  const recentActivity = [
    { course: "AWS Cloud Fundamentals", progress: 85, status: "In Progress" },
    { course: "Container Orchestration", progress: 100, status: "Completed" },
    { course: "DevOps Best Practices", progress: 45, status: "In Progress" },
    { course: "Microservices Architecture", progress: 0, status: "Not Started" }
  ];

  return (
    <div>
      <h1>Learning Dashboard</h1>
      <p className="lead">Track your learning progress and achievements</p>
      
      <div className="dashboard-stats">
        {stats.map((stat, index) => (
          <div key={index} className="stat-card">
            <h3 className={`text-${stat.color}`}>{stat.value}</h3>
            <p className="mb-0">{stat.title}</p>
          </div>
        ))}
      </div>

      <Row className="mt-4">
        <Col md={8}>
          <Card>
            <Card.Header>
              <h5>Course Progress</h5>
            </Card.Header>
            <Card.Body>
              {recentActivity.map((activity, index) => (
                <div key={index} className="mb-3">
                  <div className="d-flex justify-content-between align-items-center mb-1">
                    <span>{activity.course}</span>
                    <Badge bg={activity.status === "Completed" ? "success" : 
                              activity.status === "In Progress" ? "warning" : "secondary"}>
                      {activity.status}
                    </Badge>
                  </div>
                  <ProgressBar 
                    now={activity.progress} 
                    label={`${activity.progress}%`}
                    variant={activity.progress === 100 ? "success" : "primary"}
                  />
                </div>
              ))}
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={4}>
          <Card>
            <Card.Header>
              <h5>System Status</h5>
            </Card.Header>
            <Card.Body>
              <div className="mb-2">
                <strong>ECS Service:</strong> <Badge bg="success">Healthy</Badge>
              </div>
              <div className="mb-2">
                <strong>Load Balancer:</strong> <Badge bg="success">Active</Badge>
              </div>
              <div className="mb-2">
                <strong>Container:</strong> <Badge bg="success">Running</Badge>
              </div>
              <div className="mb-2">
                <strong>Health Checks:</strong> <Badge bg="success">Passing</Badge>
              </div>
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default Dashboard;
