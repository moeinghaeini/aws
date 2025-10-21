import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001';

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for authentication
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('authToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('authToken');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const getCourses = async () => {
  try {
    const response = await api.get('/api/courses');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch courses');
  }
};

export const getCourseById = async (id) => {
  try {
    const response = await api.get(`/api/courses/${id}`);
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch course');
  }
};

export const enrollInCourse = async (courseId) => {
  try {
    const response = await api.post(`/api/courses/${courseId}/enroll`);
    return response.data;
  } catch (error) {
    throw new Error('Failed to enroll in course');
  }
};

export const getUserProgress = async () => {
  try {
    const response = await api.get('/api/user/progress');
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch user progress');
  }
};

export default api;
