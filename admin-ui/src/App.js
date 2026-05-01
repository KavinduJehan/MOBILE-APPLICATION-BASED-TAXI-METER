import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Drivers from './pages/Drivers';
import Trips from './pages/Trips';
import PrivateRoute from './components/PrivateRoute';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/drivers"
          element={<PrivateRoute><Drivers /></PrivateRoute>}
        />
        <Route
          path="/trips"
          element={<PrivateRoute><Trips /></PrivateRoute>}
        />
        <Route path="*" element={<Navigate to="/drivers" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
