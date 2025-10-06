from unittest.mock import MagicMock, patch

import pytest
from app import app, create_access_token, get_password_hash, verify_password
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_db():
    """Mock database connection"""
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.execute.return_value = mock_cursor
    mock_conn.cursor.return_value = mock_cursor
    return mock_conn


class TestHealthCheck:
    def test_health_endpoint(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "healthy", "service": "user-service"}


class TestUserRegistration:
    @patch("app.get_db")
    def test_register_new_user_success(self, mock_get_db, client, mock_db):
        # Setup mock
        mock_get_db.return_value = mock_db
        mock_db.execute.return_value.fetchone.return_value = None  # User doesn't exist
        mock_db.execute.return_value.lastrowid = 1

        user_data = {
            "username": "testuser",
            "email": "test@example.com",
            "password": "testpass123",
        }

        response = client.post("/register", json=user_data)

        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"
        assert data["id"] == 1

    @patch("app.get_db")
    def test_register_existing_user_fails(self, mock_get_db, client, mock_db):
        # Setup mock - user already exists
        mock_get_db.return_value = mock_db
        mock_db.execute.return_value.fetchone.return_value = {"id": 1}

        user_data = {
            "username": "existinguser",
            "email": "existing@example.com",
            "password": "testpass123",
        }

        response = client.post("/register", json=user_data)

        assert response.status_code == 400
        assert "User already exists" in response.json()["detail"]


class TestUserLogin:
    @patch("app.get_db")
    def test_login_success(self, mock_get_db, client, mock_db):
        # Setup mock
        mock_get_db.return_value = mock_db
        hashed_password = get_password_hash("testpass123")
        mock_user = {
            "id": 1,
            "username": "testuser",
            "hashed_password": hashed_password,
        }
        mock_db.execute.return_value.fetchone.return_value = mock_user

        login_data = {"username": "testuser", "password": "testpass123"}

        response = client.post("/login", json=login_data)

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    @patch("app.get_db")
    def test_login_invalid_credentials(self, mock_get_db, client, mock_db):
        # Setup mock - user doesn't exist
        mock_get_db.return_value = mock_db
        mock_db.execute.return_value.fetchone.return_value = None

        login_data = {"username": "nonexistent", "password": "wrongpass"}

        response = client.post("/login", json=login_data)

        assert response.status_code == 401
        assert "Invalid credentials" in response.json()["detail"]

    @patch("app.get_db")
    def test_login_wrong_password(self, mock_get_db, client, mock_db):
        # Setup mock
        mock_get_db.return_value = mock_db
        hashed_password = get_password_hash("correctpass")
        mock_user = {
            "id": 1,
            "username": "testuser",
            "hashed_password": hashed_password,
        }
        mock_db.execute.return_value.fetchone.return_value = mock_user

        login_data = {"username": "testuser", "password": "wrongpass"}

        response = client.post("/login", json=login_data)

        assert response.status_code == 401
        assert "Invalid credentials" in response.json()["detail"]


class TestGetUser:
    @patch("app.get_db")
    def test_get_user_success(self, mock_get_db, client, mock_db):
        # Setup mock
        mock_get_db.return_value = mock_db
        mock_user = {"id": 1, "username": "testuser", "email": "test@example.com"}
        mock_db.execute.return_value.fetchone.return_value = mock_user

        response = client.get("/users/1")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == 1
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"

    @patch("app.get_db")
    def test_get_user_not_found(self, mock_get_db, client, mock_db):
        # Setup mock - user not found
        mock_get_db.return_value = mock_db
        mock_db.execute.return_value.fetchone.return_value = None

        response = client.get("/users/999")

        assert response.status_code == 404
        assert "User not found" in response.json()["detail"]


class TestAdminEndpoints:
    @patch("app.get_db")
    def test_create_admin_success(self, mock_get_db, client, mock_db):
        # Setup mock - admin doesn't exist
        mock_get_db.return_value = mock_db
        mock_db.execute.return_value.fetchone.return_value = None
        mock_db.execute.return_value.lastrowid = 1

        response = client.post("/admin/create-admin")

        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "admin"
        assert data["password"] == "admin123"

    @patch("app.get_db")
    def test_create_admin_already_exists(self, mock_get_db, client, mock_db):
        # Setup mock - admin already exists
        mock_get_db.return_value = mock_db
        mock_db.execute.return_value.fetchone.return_value = {"id": 1}

        response = client.post("/admin/create-admin")

        assert response.status_code == 200
        data = response.json()
        assert "Admin user already exists" in data["message"]

    @patch("app.get_db")
    def test_get_all_users(self, mock_get_db, client, mock_db):
        # Setup mock
        mock_get_db.return_value = mock_db
        mock_users = [
            {"id": 1, "username": "user1", "email": "user1@example.com"},
            {"id": 2, "username": "user2", "email": "user2@example.com"},
        ]
        mock_db.execute.return_value.fetchall.return_value = mock_users

        response = client.get("/admin/users")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert data[0]["username"] == "user1"
        assert data[1]["username"] == "user2"


class TestPasswordUtilities:
    def test_password_hashing_and_verification(self):
        password = "test123"
        hashed = get_password_hash(password)

        # Password should be hashed (different from original)
        assert hashed != password
        assert len(hashed) > 20  # bcrypt hashes are long

        # Verification should work
        assert verify_password(password, hashed) is True
        assert verify_password("wrongpass", hashed) is False

    def test_jwt_token_creation(self):
        test_data = {"sub": "testuser", "user_id": 1}
        token = create_access_token(test_data)

        # Token should be a string
        assert isinstance(token, str)
        assert len(token) > 50  # JWT tokens are long

        # Should contain JWT structure (header.payload.signature)
        assert token.count(".") == 2


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
