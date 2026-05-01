import { Navigate } from 'react-router-dom';

// Wraps a route — redirects to /login if no token in localStorage
export default function PrivateRoute({ children }) {
  const token = localStorage.getItem('adminToken');
  return token ? children : <Navigate to="/login" replace />;
}
