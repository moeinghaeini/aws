import React from 'react';
import { render, screen } from '@testing-library/react';
import App from '../App';

describe('LMS Frontend App', () => {
  test('renders without crashing', () => {
    render(<App />);
    
    // Basic smoke test - app should render without errors
    expect(document.body).toBeInTheDocument();
  });

  test('renders main navigation', () => {
    render(<App />);
    
    // Check if navigation elements are present
    const navElement = document.querySelector('nav');
    expect(navElement).toBeInTheDocument();
  });

  test('has proper HTML structure', () => {
    render(<App />);
    
    // Check for basic HTML structure
    expect(document.querySelector('div')).toBeInTheDocument();
  });
});
