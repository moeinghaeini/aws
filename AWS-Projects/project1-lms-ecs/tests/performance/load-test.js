const k6 = require('k6');
const http = require('k6/http');
const { check, sleep } = require('k6');

// Load test configuration
export let options = {
  stages: [
    { duration: '2m', target: 10 }, // Ramp up to 10 users
    { duration: '5m', target: 10 }, // Stay at 10 users
    { duration: '2m', target: 20 }, // Ramp up to 20 users
    { duration: '5m', target: 20 }, // Stay at 20 users
    { duration: '2m', target: 0 },  // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    http_req_failed: ['rate<0.1'],     // Error rate must be below 10%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function() {
  // Test home page
  let response = http.get(`${BASE_URL}/`);
  check(response, {
    'home page status is 200': (r) => r.status === 200,
    'home page response time < 2s': (r) => r.timings.duration < 2000,
  });

  sleep(1);

  // Test courses page
  response = http.get(`${BASE_URL}/courses`);
  check(response, {
    'courses page status is 200': (r) => r.status === 200,
    'courses page response time < 2s': (r) => r.timings.duration < 2000,
  });

  sleep(1);

  // Test API endpoints
  response = http.get(`${BASE_URL}/api/courses`);
  check(response, {
    'API courses status is 200': (r) => r.status === 200,
    'API courses response time < 1s': (r) => r.timings.duration < 1000,
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'load-test-results.json': JSON.stringify(data, null, 2),
  };
}
