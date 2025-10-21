import React from 'react';
import { Card, Button, Row, Col, Badge } from 'react-bootstrap';

const Courses = () => {
  const courses = [
    {
      id: 1,
      title: "AWS Cloud Fundamentals",
      description: "Learn the basics of AWS cloud computing and services.",
      duration: "4 weeks",
      level: "Beginner",
      price: "$99"
    },
    {
      id: 2,
      title: "Container Orchestration with ECS",
      description: "Master container deployment and management on AWS ECS.",
      duration: "6 weeks",
      level: "Intermediate",
      price: "$149"
    },
    {
      id: 3,
      title: "DevOps Best Practices",
      description: "Learn modern DevOps practices and CI/CD pipelines.",
      duration: "8 weeks",
      level: "Advanced",
      price: "$199"
    },
    {
      id: 4,
      title: "Microservices Architecture",
      description: "Design and implement scalable microservices architectures.",
      duration: "10 weeks",
      level: "Advanced",
      price: "$249"
    }
  ];

  return (
    <div>
      <h1>Available Courses</h1>
      <p className="lead">Choose from our comprehensive course catalog</p>
      
      <Row>
        {courses.map(course => (
          <Col md={6} key={course.id} className="mb-4">
            <Card className="course-card">
              <Card.Body>
                <Card.Title>{course.title}</Card.Title>
                <Card.Text>{course.description}</Card.Text>
                <div className="mb-3">
                  <Badge bg="info" className="me-2">{course.level}</Badge>
                  <Badge bg="secondary" className="me-2">{course.duration}</Badge>
                  <Badge bg="success">{course.price}</Badge>
                </div>
                <Button variant="primary" className="me-2">Enroll Now</Button>
                <Button variant="outline-secondary">Learn More</Button>
              </Card.Body>
            </Card>
          </Col>
        ))}
      </Row>
    </div>
  );
};

export default Courses;
