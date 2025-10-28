import os
from datetime import datetime, timedelta
from typing import List

import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt
from passlib.context import CryptContext
from pydantic import BaseModel

app = FastAPI(title="User Service", version="1.0.0")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your frontend domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class UserCreate(BaseModel):
    username: str
    email: str
    password: str


class UserLogin(BaseModel):
    username: str
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str


class User(BaseModel):
    id: int
    username: str
    email: str


# Database setup
def get_db():
    """Get PostgreSQL database connection"""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise ValueError("DATABASE_URL environment variable is required")
    conn = psycopg2.connect(database_url, cursor_factory=RealDictCursor)
    return conn


def init_db():
    """Initialize database schema"""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(255) UNIQUE NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            hashed_password TEXT NOT NULL
        )
    """
    )
    conn.commit()
    cursor.close()
    conn.close()


def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password):
    return pwd_context.hash(password)


def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


@app.on_event("startup")
async def startup_event():
    try:
        init_db()
    except Exception:
        # In test environment, database might not be available
        pass


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "user-service"}


@app.post("/register", response_model=User)
async def register(user: UserCreate):
    conn = get_db()
    cursor = conn.cursor()
    try:
        # Check if user exists
        cursor.execute(
            "SELECT id FROM users WHERE username = %s OR email = %s",
            (user.username, user.email),
        )
        existing = cursor.fetchone()

        if existing:
            raise HTTPException(status_code=400, detail="User already exists")

        # Create user
        hashed_password = get_password_hash(user.password)
        cursor.execute(
            "INSERT INTO users (username, email, hashed_password) VALUES (%s, %s, %s) RETURNING id",
            (user.username, user.email, hashed_password),
        )
        user_id = cursor.fetchone()["id"]
        conn.commit()

        return User(id=user_id, username=user.username, email=user.email)
    finally:
        cursor.close()
        conn.close()


@app.post("/login", response_model=Token)
async def login(user_login: UserLogin):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT id, username, hashed_password FROM users WHERE username = %s",
            (user_login.username,),
        )
        user = cursor.fetchone()

        if not user or not verify_password(
            user_login.password, user["hashed_password"]
        ):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        access_token = create_access_token(
            data={"sub": user["username"], "user_id": user["id"]}
        )
        return {"access_token": access_token, "token_type": "bearer"}
    finally:
        cursor.close()
        conn.close()


@app.get("/users/{user_id}", response_model=User)
async def get_user(user_id: int):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT id, username, email FROM users WHERE id = %s", (user_id,)
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        return User(id=user["id"], username=user["username"], email=user["email"])
    finally:
        cursor.close()
        conn.close()


@app.get("/admin/users", response_model=List[User])
async def get_all_users():
    """Admin endpoint to get all users"""
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT id, username, email FROM users ORDER BY id"
        )
        users = cursor.fetchall()

        return [
            User(id=user["id"], username=user["username"], email=user["email"])
            for user in users
        ]
    finally:
        cursor.close()
        conn.close()


@app.post("/admin/create-admin")
async def create_admin():
    """Create default admin user"""
    conn = get_db()
    cursor = conn.cursor()
    try:
        # Check if admin already exists
        cursor.execute(
            "SELECT id FROM users WHERE username = %s", ("admin",)
        )
        existing = cursor.fetchone()

        if existing:
            return {"message": "Admin user already exists", "username": "admin"}

        # Create admin user with password from environment variable
        default_password = os.getenv("ADMIN_DEFAULT_PASSWORD", "ChangeMe123!")
        hashed_password = get_password_hash(default_password)
        cursor.execute(
            "INSERT INTO users (username, email, hashed_password) VALUES (%s, %s, %s) RETURNING id",
            ("admin", "admin@devops-todo.com", hashed_password),
        )
        user_id = cursor.fetchone()["id"]
        conn.commit()

        return {
            "message": "Admin user created - CHANGE PASSWORD IMMEDIATELY",
            "username": "admin",
            "id": user_id,
        }
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8001)
