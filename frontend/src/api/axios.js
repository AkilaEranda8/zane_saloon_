import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Redirect to /login on 401 Unauthorized (but not when already on /login,
// which would cause an infinite reload loop during the initial auth check)
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (
      error.response?.status === 401 &&
      window.location.pathname !== '/login'
    ) {
      localStorage.removeItem('luxesalon_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
