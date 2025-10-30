import os
from typing import List, Optional

import psycopg2

# httpx removed - not used
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from jose import JWTError, jwt
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel

app = FastAPI(title="Todo Service", version="1.0.0")

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
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://user-service:8001")

# SQL Queries
SQL_GET_TODO_BY_ID_AND_USER = "SELECT * FROM todos WHERE id = %s AND user_id = %s"

# Error messages
ERROR_TODO_NOT_FOUND = "Todo not found"


class TodoCreate(BaseModel):
    title: str
    description: Optional[str] = None


class TodoUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    completed: Optional[bool] = None


class Todo(BaseModel):
    id: int
    title: str
    description: Optional[str]
    completed: bool
    user_id: int
    created_at: str


# Database setup
def get_db():  # pragma: no cover
    """Get PostgreSQL database connection"""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise ValueError("DATABASE_URL environment variable is required")
    conn = psycopg2.connect(database_url, cursor_factory=RealDictCursor)
    return conn


def init_db():  # pragma: no cover
    """Initialize database schema"""
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS todos (
            id SERIAL PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            completed BOOLEAN DEFAULT FALSE,
            user_id INTEGER NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """
    )
    conn.commit()
    cursor.close()
    conn.close()


async def verify_token(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")

    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("user_id")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


@app.on_event("startup")
async def startup_event():  # pragma: no cover
    try:
        init_db()
    except Exception:
        # In test environment, database might not be available
        pass


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "todo-service"}


@app.post("/todos", response_model=Todo)
async def create_todo(todo: TodoCreate, user_id: int = Depends(verify_token)):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO todos (title, description, user_id) "
            "VALUES (%s, %s, %s) RETURNING *",
            (todo.title, todo.description, user_id),
        )
        created_todo = cursor.fetchone()
        conn.commit()

        return Todo(
            id=created_todo["id"],
            title=created_todo["title"],
            description=created_todo["description"],
            completed=bool(created_todo["completed"]),
            user_id=created_todo["user_id"],
            created_at=str(created_todo["created_at"]),
        )
    finally:
        cursor.close()
        conn.close()


@app.get("/todos", response_model=List[Todo])
async def get_todos(user_id: int = Depends(verify_token)):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT * FROM todos WHERE user_id = %s " "ORDER BY created_at DESC",
            (user_id,),
        )
        todos = cursor.fetchall()

        return [
            Todo(
                id=todo["id"],
                title=todo["title"],
                description=todo["description"],
                completed=bool(todo["completed"]),
                user_id=todo["user_id"],
                created_at=str(todo["created_at"]),
            )
            for todo in todos
        ]
    finally:
        cursor.close()
        conn.close()


@app.get("/todos/{todo_id}", response_model=Todo)
async def get_todo(todo_id: int, user_id: int = Depends(verify_token)):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute(SQL_GET_TODO_BY_ID_AND_USER, (todo_id, user_id))
        todo = cursor.fetchone()

        if not todo:
            raise HTTPException(status_code=404, detail=ERROR_TODO_NOT_FOUND)

        return Todo(
            id=todo["id"],
            title=todo["title"],
            description=todo["description"],
            completed=bool(todo["completed"]),
            user_id=todo["user_id"],
            created_at=str(todo["created_at"]),
        )
    finally:
        cursor.close()
        conn.close()


@app.put("/todos/{todo_id}", response_model=Todo)
async def update_todo(
    todo_id: int, todo_update: TodoUpdate, user_id: int = Depends(verify_token)
):
    conn = get_db()
    cursor = conn.cursor()
    try:
        # Check if todo exists and belongs to user
        cursor.execute(SQL_GET_TODO_BY_ID_AND_USER, (todo_id, user_id))
        existing = cursor.fetchone()

        if not existing:
            raise HTTPException(status_code=404, detail=ERROR_TODO_NOT_FOUND)

        # Update fields
        update_data = {}
        if todo_update.title is not None:
            update_data["title"] = todo_update.title
        if todo_update.description is not None:
            update_data["description"] = todo_update.description
        if todo_update.completed is not None:
            update_data["completed"] = todo_update.completed

        if update_data:
            set_clause = ", ".join([f"{key} = %s" for key in update_data.keys()])
            values = list(update_data.values()) + [todo_id, user_id]

            cursor.execute(
                f"UPDATE todos SET {set_clause} WHERE id = %s AND user_id = %s", values
            )
            conn.commit()

        # Get updated todo
        cursor.execute(SQL_GET_TODO_BY_ID_AND_USER, (todo_id, user_id))
        updated_todo = cursor.fetchone()

        return Todo(
            id=updated_todo["id"],
            title=updated_todo["title"],
            description=updated_todo["description"],
            completed=bool(updated_todo["completed"]),
            user_id=updated_todo["user_id"],
            created_at=str(updated_todo["created_at"]),
        )
    finally:
        cursor.close()
        conn.close()


@app.delete("/todos/{todo_id}")
async def delete_todo(todo_id: int, user_id: int = Depends(verify_token)):
    conn = get_db()
    cursor = conn.cursor()
    try:
        # Check if todo exists and belongs to user
        cursor.execute(
            "SELECT id FROM todos WHERE id = %s AND user_id = %s", (todo_id, user_id)
        )
        existing = cursor.fetchone()

        if not existing:
            raise HTTPException(status_code=404, detail=ERROR_TODO_NOT_FOUND)

        cursor.execute(
            "DELETE FROM todos WHERE id = %s AND user_id = %s", (todo_id, user_id)
        )
        conn.commit()

        return {"message": "Todo deleted successfully"}
    finally:
        cursor.close()
        conn.close()


@app.get("/admin/todos", response_model=List[Todo])
async def get_all_todos():
    """Admin endpoint to get all todos"""
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM todos ORDER BY created_at DESC")
        todos = cursor.fetchall()

        return [
            Todo(
                id=todo["id"],
                title=todo["title"],
                description=todo["description"],
                completed=bool(todo["completed"]),
                user_id=todo["user_id"],
                created_at=str(todo["created_at"]),
            )
            for todo in todos
        ]
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8002)
