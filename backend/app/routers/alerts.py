"""Price alerts and the notifications they create."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Alert, Notification, User
from ..schemas import AlertIn, AlertOut, NotificationOut
from ..security import current_user
router = APIRouter(prefix="/api", tags=["Alerts"])
def _own(db: Session, user: User, alert_id: int) -> Alert:
    a = db.get(Alert, alert_id)
    if a is None or a.user_id != user.id:
        raise HTTPException(404, "Alert not found.")
    return a
@router.get("/alerts", response_model=list[AlertOut])
def list_alerts(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return db.scalars(select(Alert).where(Alert.user_id == user.id).order_by(Alert.created_at.desc())).all()
@router.post("/alerts", response_model=AlertOut, status_code=201)
def create_alert(body: AlertIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    a = Alert(user_id=user.id, symbol=body.symbol.upper(), kind=body.kind, value=body.value)
    db.add(a)
    db.commit()
    db.refresh(a)
    return a
@router.patch("/alerts/{alert_id}/toggle", response_model=AlertOut)
def toggle_alert(alert_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    a = _own(db, user, alert_id)
    a.active = not a.active
    if a.active:
        a.triggered_at = None
    db.commit()
    db.refresh(a)
    return a
@router.delete("/alerts/{alert_id}", status_code=204)
def delete_alert(alert_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    db.delete(_own(db, user, alert_id))
    db.commit()
@router.get("/notifications", response_model=list[NotificationOut])
def notifications(unseen_only: bool = False, user: User = Depends(current_user), db: Session = Depends(get_db)):
    q = select(Notification).where(Notification.user_id == user.id)
    if unseen_only:
        q = q.where(Notification.seen.is_(False))
    return db.scalars(q.order_by(Notification.created_at.desc()).limit(50)).all()
@router.post("/notifications/seen", status_code=204)
def mark_seen(user: User = Depends(current_user), db: Session = Depends(get_db)):
    db.execute(update(Notification).where(Notification.user_id == user.id).values(seen=True))
    db.commit()
