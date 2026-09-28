import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Drivers from './pages/Drivers';
import Trips from './pages/Trips';
import Dashboard from './pages/Dashboard';
import Pricing from './pages/Pricing';
import PrivateRoute from './components/PrivateRoute';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/dashboard"
          element={<PrivateRoute><Dashboard /></PrivateRoute>}
        />
        <Route
          path="/drivers"
          element={<PrivateRoute><Drivers /></PrivateRoute>}
        />
        <Route
          path="/trips"
          element={<PrivateRoute><Trips /></PrivateRoute>}
        />
        <Route
          path="/pricing"
          element={<PrivateRoute><Pricing /></PrivateRoute>}
        />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
