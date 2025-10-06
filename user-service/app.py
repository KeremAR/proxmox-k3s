import os
import sqlite3
from datetime import datetime, timedelta
from typing import List

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
    db_path = "/app/data/users.db"
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            hashed_password TEXT NOT NULL
        )
    """
    )
    conn.commit()
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
    init_db()


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "user-service"}


@app.post("/register", response_model=User)
async def register(user: UserCreate):
    conn = get_db()
    try:
        # Check if user exists
        existing = conn.execute(
            "SELECT id FROM users WHERE username = ? OR email = ?",
            (user.username, user.email),
        ).fetchone()

        if existing:
            raise HTTPException(status_code=400, detail="User already exists")

        # Create user
        hashed_password = get_password_hash(user.password)
        cursor = conn.execute(
            "INSERT INTO users (username, email, hashed_password) VALUES (?, ?, ?)",
            (user.username, user.email, hashed_password),
        )
        conn.commit()

        return User(id=cursor.lastrowid, username=user.username, email=user.email)
    finally:
        conn.close()


@app.post("/login", response_model=Token)
async def login(user_login: UserLogin):
    conn = get_db()
    try:
        user = conn.execute(
            "SELECT id, username, hashed_password FROM users WHERE username = ?",
            (user_login.username,),
        ).fetchone()

        if not user or not verify_password(
            user_login.password, user["hashed_password"]
        ):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        access_token = create_access_token(
            data={"sub": user["username"], "user_id": user["id"]}
        )
        return {"access_token": access_token, "token_type": "bearer"}
    finally:
        conn.close()


@app.get("/users/{user_id}", response_model=User)
async def get_user(user_id: int):
    conn = get_db()
    try:
        user = conn.execute(
            "SELECT id, username, email FROM users WHERE id = ?", (user_id,)
        ).fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        return User(id=user["id"], username=user["username"], email=user["email"])
    finally:
        conn.close()


@app.get("/admin/users", response_model=List[User])
async def get_all_users():
    """Admin endpoint to get all users"""
    conn = get_db()
    try:
        users = conn.execute(
            "SELECT id, username, email FROM users ORDER BY id"
        ).fetchall()

        return [
            User(id=user["id"], username=user["username"], email=user["email"])
            for user in users
        ]
    finally:
        conn.close()


@app.post("/admin/create-admin")
async def create_admin():
    """Create default admin user"""
    conn = get_db()
    try:
        # Check if admin already exists
        existing = conn.execute(
            "SELECT id FROM users WHERE username = ?", ("admin",)
        ).fetchone()

        if existing:
            return {"message": "Admin user already exists", "username": "admin"}

        # Create admin user
        hashed_password = get_password_hash("admin123")
        cursor = conn.execute(
            "INSERT INTO users (username, email, hashed_password) VALUES (?, ?, ?)",
            ("admin", "admin@devops-todo.com", hashed_password),
        )
        conn.commit()

        return {
            "message": "Admin user created",
            "username": "admin",
            "password": "admin123",
            "id": cursor.lastrowid,
        }
    finally:
        conn.close()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8001)
