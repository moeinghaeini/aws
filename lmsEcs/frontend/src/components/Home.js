import React from 'react';
import { Card, Button, Row, Col } from 'react-bootstrap';

const Home = () => {
  return (
    <div>
      <div className="health-check">
        <h4>✅ LMS Application Health Check</h4>
        <p>Application is running successfully on AWS ECS Fargate!</p>
        <p><strong>Environment:</strong> Production | <strong>Status:</strong> Healthy</p>
      </div>
      
      <h1>Welcome to LMS Platform</h1>
      <p className="lead">Your containerized Learning Management System deployed on AWS ECS</p>
      
      <Row className="mt-4">
        <Col md={4}>
          <Card>
            <Card.Body>
              <Card.Title>📚 Courses</Card.Title>
              <Card.Text>
                Browse and enroll in various courses available on our platform.
              </Card.Text>
              <Button variant="primary" href="/courses">View Courses</Button>
            </Card.Body>
          </Card>
        </Col>
        <Col md={4}>
          <Card>
            <Card.Body>
              <Card.Title>📊 Dashboard</Card.Title>
              <Card.Text>
                Track your learning progress and view your achievements.
              </Card.Text>
              <Button variant="primary" href="/dashboard">Go to Dashboard</Button>
            </Card.Body>
          </Card>
        </Col>
        <Col md={4}>
          <Card>
            <Card.Body>
              <Card.Title>🔧 Technical Info</Card.Title>
              <Card.Text>
                <strong>Deployment:</strong> AWS ECS Fargate<br/>
                <strong>Load Balancer:</strong> ALB<br/>
                <strong>Container:</strong> Docker
              </Card.Text>
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default Home;
