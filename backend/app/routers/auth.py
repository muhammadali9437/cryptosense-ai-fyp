"""Register, log in, and "who am I"."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User
from ..schemas import LoginIn, RegisterIn, TokenOut, UserOut
from ..security import create_token, current_user, hash_password, verify_password
router = APIRouter(prefix="/api/auth", tags=["Auth"])
def _out(u: User) -> UserOut:
    return UserOut(id=u.id, name=u.name, email=u.email)
@router.post("/register", response_model=TokenOut, status_code=201)
def register(body: RegisterIn, db: Session = Depends(get_db)):
    email = body.email.lower().strip()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status.HTTP_409_CONFLICT, "An account with this email already exists.")
    user = User(name=body.name.strip(), email=email, password_hash=hash_password(body.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return TokenOut(access_token=create_token(user.id), user=_out(user))
@router.post("/login", response_model=TokenOut)
def login(body: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == body.email.lower().strip()))
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong email or password.")
    return TokenOut(access_token=create_token(user.id), user=_out(user))
@router.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return _out(user)
