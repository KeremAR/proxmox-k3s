import { useState } from 'react';

const USER_SERVICE_URL = 'http://todo-app.local';

const LoginPage = ({ onLogin }) => {
  const [showLogin, setShowLogin] = useState(true);
  const [authForm, setAuthForm] = useState({
    username: '',
    email: '',
    password: '',
  });

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setAuthForm(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const login = async () => {
    try {
      const response = await fetch(`${USER_SERVICE_URL}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: authForm.username,
          password: authForm.password,
        }),
      });

      if (response.ok) {
        const { access_token } = await response.json();
        const userData = {
          id: 1,
          username: authForm.username,
          email: authForm.username + '@example.com',
        };

        localStorage.setItem('token', access_token);
        localStorage.setItem('user', JSON.stringify(userData));
        onLogin(access_token, userData);
      } else {
        alert('Login failed');
      }
    } catch (error) {
      console.error('Login failed:', error);
      alert('Login failed');
    }
  };

  const register = async () => {
    try {
      const response = await fetch(`${USER_SERVICE_URL}/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(authForm),
      });

      if (response.ok) {
        alert('Registration successful! Please login.');
        setShowLogin(true);
      } else {
        alert('Registration failed');
      }
    } catch (error) {
      console.error('Registration failed:', error);
      alert('Registration failed');
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="max-w-md w-full mx-auto">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h1 className="text-2xl font-bold text-center mb-6 text-gray-900">
            DevOps Todo App
          </h1>
          <div className="flex mb-4">
            <button
              className={`flex-1 py-2 px-4 rounded-l-lg ${
                showLogin ? 'bg-blue-500 text-white' : 'bg-gray-200'
              }`}
              onClick={() => setShowLogin(true)}
            >
              Login
            </button>
            <button
              className={`flex-1 py-2 px-4 rounded-r-lg ${
                !showLogin ? 'bg-blue-500 text-white' : 'bg-gray-200'
              }`}
              onClick={() => setShowLogin(false)}
            >
              Register
            </button>
          </div>

          <div className="space-y-4">
            <input
              type="text"
              name="username"
              placeholder="Username"
              className="w-full p-3 border border-gray-300 rounded-lg text-gray-900 placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              value={authForm.username}
              onChange={handleInputChange}
            />
            {!showLogin && (
              <input
                type="email"
                name="email"
                placeholder="Email"
                className="w-full p-3 border border-gray-300 rounded-lg text-gray-900 placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                value={authForm.email}
                onChange={handleInputChange}
              />
            )}
            <input
              type="password"
              name="password"
              placeholder="Password"
              className="w-full p-3 border border-gray-300 rounded-lg text-gray-900 placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              value={authForm.password}
              onChange={handleInputChange}
            />
            <button
              className="w-full bg-blue-500 text-white py-3 rounded-lg hover:bg-blue-600"
              onClick={showLogin ? login : register}
            >
              {showLogin ? 'Login' : 'Register'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
