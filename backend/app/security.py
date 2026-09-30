"""Password hashing (bcrypt) and login tokens (JWT)."""
from datetime import datetime, timedelta, timezone
import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
from .config import settings
from .database import get_db
from .models import User
_bearer = HTTPBearer(auto_error=False)
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode(), hashed.encode())
    except ValueError:
        return False
def create_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")
def _user_from(creds: HTTPAuthorizationCredentials | None, db: Session) -> User | None:
    if creds is None:
        return None
    try:
        payload = jwt.decode(creds.credentials, settings.jwt_secret, algorithms=["HS256"])
        return db.get(User, int(payload["sub"]))
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer), db: Session = Depends(get_db)
) -> User:
    """Dependency for routes that need a logged-in user."""
    user = _user_from(creds, db)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Please log in first.")
    return user
def optional_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer), db: Session = Depends(get_db)
) -> User | None:
    """Dependency for routes that work with or without login (e.g. chat)."""
    return _user_from(creds, db)
