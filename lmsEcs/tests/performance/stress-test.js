const k6 = require('k6');
const http = require('k6/http');
const { check, sleep } = require('k6');

// Stress test configuration
export let options = {
  stages: [
    { duration: '2m', target: 10 },  // Ramp up to 10 users
    { duration: '5m', target: 10 },  // Stay at 10 users
    { duration: '2m', target: 50 },  // Ramp up to 50 users
    { duration: '5m', target: 50 },  // Stay at 50 users
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'], // 95% of requests must complete below 5s
    http_req_failed: ['rate<0.2'],     // Error rate must be below 20%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function() {
  // Test concurrent API calls
  let responses = http.batch([
    ['GET', `${BASE_URL}/api/courses`],
    ['GET', `${BASE_URL}/api/courses/1`],
    ['GET', `${BASE_URL}/api/user/progress`],
  ]);

  check(responses[0], {
    'API courses status is 200': (r) => r.status === 200,
  });

  check(responses[1], {
    'API course detail status is 200': (r) => r.status === 200,
  });

  check(responses[2], {
    'API user progress status is 200': (r) => r.status === 200,
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'stress-test-results.json': JSON.stringify(data, null, 2),
  };
}
